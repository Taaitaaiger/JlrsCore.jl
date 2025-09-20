module Reflect
using Base: IdSet, IdDict
export reflect, constant_type_var, renamestruct!, renamefields!, overridepath!
import Base: show, getindex, write

abstract type Layout end

struct StructParameter
    name::Symbol
    elide::Bool
end

struct TypeParameter
    name::Symbol
    value
end

struct GenericLayout <: Layout
    name::Symbol
end

mutable struct StructField
    name::Symbol
    rsname::String
    fieldtype::Layout
    typeparams::Vector{TypeParameter}
    referenced::IdSet{TypeVar}
    scopelifetime::Bool
    datalifetime::Bool
    asvalue::Bool
end

struct BitsUnionLayout <: Layout
    union_of::Union
    typeparams::Vector{StructParameter}
    scopelifetime::Bool
    datalifetime::Bool
    BitsUnionLayout(union_of::Union) = new(union_of, [], false, false)
end

mutable struct StructLayout <: Layout
    name::Symbol
    typename::Core.TypeName
    type::DataType
    rsname::String
    path::String
    fields::Vector{StructField}
    typeparams::Vector{StructParameter}
    scopelifetime::Bool
    datalifetime::Bool
end

mutable struct ContainsAtomicFieldsLayout <: Layout
    name::Symbol
    typename::Core.TypeName
    type::DataType
    rsname::String
    path::String
    #fields::Vector{StructField}
    typeparams::Vector{StructParameter}
    #scopelifetime::Bool
    #datalifetime::Bool
end

mutable struct AbstractTypeLayout <: Layout
    name::Symbol
    typename::Core.TypeName
    type::DataType
    rsname::String
    path::String
    typeparams::Vector{StructParameter}
end

struct TupleField
    fieldtype::Layout
    typeparams::Vector{TypeParameter}
    scopelifetime::Bool
    datalifetime::Bool
end

struct TupleLayout <: Layout
    rsname::String
    fields::Vector{TupleField}
    scopelifetime::Bool
    datalifetime::Bool
    TupleLayout(fields::Vector{TupleField}, scopelifetime::Bool, datalifetime::Bool) = new("::jlrs::data::layout::tuple::Tuple$(length(fields))", fields, scopelifetime, datalifetime)
end

struct BuiltinLayout <: Layout
    rsname::String
    typeparams::Vector{StructParameter}
    scopelifetime::Bool
    datalifetime::Bool
    pointerfield::Bool
end

mutable struct EnumVariant
    name::Symbol
    rsname::String
    value
end

mutable struct EnumLayout <: Layout
    name::Symbol
    type::DataType
    rsname::String
    path::String
    fields::Vector{EnumVariant}
end

struct BuiltinAbstractLayout <: Layout
end

struct UnsupportedLayout <: Layout
    reason::String
end

struct Layouts
    typed_bits_union::Bool
    dict::IdDict{DataType,Layout}
end

struct StringLayouts
    dict::IdDict{DataType,String}
end

"""
    reflect(types::Vector{<:Type}; f16::Bool=false, complex::Bool=false, typed_bits_union::Bool=false)::Layouts

Generate Rust layouts and type constructors for all types in `types` and their dependencies. The
only requirement is that these types must not contain any union or tuple fields that directly
depend on a type parameter.

A layout is a Rust type whose layout exactly matches the layout of the Julia type it's reflected
from. Layouts are generated for the most general case by erasing the content of all provided type
parameters, so you can't avoid the restrictions regarding union and tuple fields with type
parameters by explicitly providing a more qualified type. The only effect qualifying types has, is
that layouts for the used parameters will also be generated. If a type parameter doesn't affect
its layout it's elided from the generated layout.

Layouts automatically derive a bunch of traits to enable using them with jlrs. The following
traits will be implemented as long as their requirements are met:

- `Clone` and `Debug` are always derived.

- `ValidLayout` is always derived, enables checking if the layout of a Julia type is compatible
  with that Rust type. `Typecheck` is always derived, and is implemented as a call to
  `ValidLayout::valid_layout`.

- `Unbox` is always derived, enables converting Julia data to an instance of this type by casting
  and dereferencing the internal pointer of a `Value`, and then cloning the contents.

- `ValidField` is derived if this type is stored inline when used as a field type, which is
  generally the case if the Julia type is immutable and concrete. `ValidLayout` and `ValidField`
  are implemented by calling `ValidField::valid_field` for each field.

- `IntoJulia` is derived if the type is an `isbits`` type with no type parameters, enables
  converting data of that type directly to a `Value` with `Value::new`. The `Value` is allocated
  by creating a new uninitialized struct and copying the data into it.

- `ConstructType` is derived if no type parameters have been elided, if the generated struct does
  have elided parameters, a zero-sized struct named `{type_name}TypeConstructor` is additionally
  generated which elides no parameters and derives nothing but this trait. This trait enables the
  Julia type associated with the Rust type to be constructed without depending on any existing
  data.

- `CCallArg` and `CCallReturn` are derived if the type is immutable, these types can be used in
  argument and return positions with Rust functions that are called from Julia through `ccall`.
  Mutable types don't implement this trait so they can't be used in Rust signatures directly,
  `TypedValue` must be used to guarantee the data is passed by reference rather than by value.

The result of this function can be written to a file, its contents should be a valid Rust module
when the jlrs prelude is imported.

When you use these layouts with jlrs, the types they've been generated from must be available with
the same path at generation time and run time. For example, if you generate a layout for
`Main.Bar.Baz`, this type must be available through that path and not some other path like
`Main.Foo.Bar.Baz`. The path can be overriden by calling `overridepath!`.

# Example
```jldoctest
julia> using JlrsCore.Reflect

julia> reflect([Complex])
#[repr(C)]
#[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, IsBits, ConstructType, CCallArg, CCallReturn)]
#[jlrs(julia_type = "Base.Complex")]
pub struct Complex<T> {
    pub re: T,
    pub im: T,
}
```
"""
function reflect(types::Vector{<:Type}; f16::Bool=false, complex::Bool=false, typed_bits_union::Bool=false)::Layouts
    deps = IdDict{DataType,IdSet{DataType}}()
    layouts = IdDict{DataType,Layout}()
    insertbuiltins!(layouts)

    if f16
        layouts[Float16] = BuiltinLayout("::half::f16", [], false, false, false)
    else
        layouts[Float16] = UnsupportedLayout("Layouts with Float16 fields can only be generated when f16 is set to true.")
    end

    if complex
        layouts[basetype(Complex)] = BuiltinLayout("::num::Complex", [StructParameter(:T, false)], false, false, false)
    end

    for ty in types
        extractdeps!(deps, ty, layouts)
    end

    # Topologically sort all types so every layout the current type depends on has already been
    # generated
    for ty in toposort!(deps)
        createlayout!(layouts, ty)
    end

    # If any of the fields of a generated layout contain a parameter with lifetimes, these
    # lifetimes must be propagated to the layout's parameters.
    propagate_internal_param_lifetimes!(layouts)
    Layouts(typed_bits_union, layouts)
end

"""
    renamestruct!(layouts::Layouts, type::Type, rename::String)

Change a struct's name. This can be useful if the name of a struct results in invalid Rust code or
causes warnings.

# Example
```jldoctest
julia> using JlrsCore.Reflect

julia> struct Foo end

julia> layouts = reflect([Foo]);

julia> renamestruct!(layouts, Foo, "Bar")

julia> layouts
#[repr(C)]
#[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, IsBits, ConstructType)]
#[jlrs(julia_type = "Main.Foo", zero_sized_type)]
pub struct Bar {
}
```
"""
function renamestruct!(layouts::Layouts, type::Type, rename::String)::Nothing
    btype::DataType = basetype(type)
    layouts.dict[btype].rsname = rename

    nothing
end

"""
    renamefields!(layouts::Layouts, type::Type, rename::Dict{Symbol,String})
    renamefields!(layouts::Layouts, type::Type, rename::Vector{Pair{Symbol,String})

Change some field names of a struct. This can be useful if the name of a struct results in invalid
Rust code or causes warnings.

# Example
```jldoctest
julia> using JlrsCore.Reflect

julia> struct Food burger::Bool end

julia> layouts = reflect([Food]);

julia> renamefields!(layouts, Food, [:burger => "hamburger"])

julia> layouts
#[repr(C)]
#[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, IsBits, ConstructType, CCallArg, CCallReturn)]
#[jlrs(julia_type = "Main.Food")]
pub struct Food {
    pub hamburger: ::jlrs::data::layout::bool::Bool,
}

```
"""
function renamefields! end

function renamefields!(layouts::Layouts, type::Type, rename::Dict{Symbol,String})::Nothing
    btype::DataType = basetype(type)
    for field in layouts.dict[btype].fields
        if field.name in keys(rename)
            field.rsname = rename[field.name]
        end
    end

    nothing
end

function renamefields!(layouts::Layouts, type::Type, rename::Vector{Pair{Symbol,String}})::Nothing
    renamefields!(layouts, type, Dict(rename))
end

"""
    overridepath!(layouts::Layouts, type::Type, path::String)

Change a struct's type path. This can be useful if the struct is loaded in a different module at
runtime.

# Example
```jldoctest
julia> using JlrsCore.Reflect

julia> struct Foo end

julia> layouts = reflect([Foo]);

julia> overridepath!(layouts, Foo, "Main.A.Bar")

julia> layouts
#[repr(C)]
#[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, IsBits, ConstructType)]
#[jlrs(julia_type = "Main.A.Bar", zero_sized_type)]
pub struct Foo {
}
```
"""
function overridepath!(layouts::Layouts, type::Type, path::String)::Nothing
    btype::DataType = basetype(type)
    layouts.dict[btype].path = path

    nothing
end

if VERSION.minor == 6
    function ismutabletype(t)
        t.mutable
    end
end

function StringLayouts(layouts::Layouts)
    strlayouts = IdDict{DataType,String}()

    for (name, value) in pairs(layouts.dict)
        rustimpl = strlayout(value, layouts.dict, layouts.typed_bits_union)
        if rustimpl !== nothing
            strlayouts[name] = rustimpl
        end
    end

    StringLayouts(strlayouts)
end

function getindex(sb::StringLayouts, els...)
    sb.dict[els...]
end

function show(io::IO, layouts::Layouts)
    rustimpls = []
    names = []

    for name in keys(layouts.dict)
        push!(names, name)
    end

    for name in sort(names, lt=(a, b) -> string(a) < string(b))
        rustimpl = strlayout(layouts.dict[name], layouts.dict, layouts.typed_bits_union)
        if rustimpl !== nothing
            push!(rustimpls, rustimpl)
        end
    end

    print(io, join(rustimpls, "\n\n"))
end

function write(io::IO, layouts::Layouts)
    rustimpls = ["use jlrs::prelude::*;"]
    names = []

    for name in keys(layouts.dict)
        push!(names, name)
    end

    for name in sort(names, lt=(a, b) -> string(a) < string(b))
        rustimpl = strlayout(layouts.dict[name], layouts.dict, layouts.typed_bits_union)
        if rustimpl !== nothing
            push!(rustimpls, rustimpl)
        end
    end

    write(io, join(rustimpls, "\n\n"))
end

function toposort!(data::IdDict{DataType, IdSet{DataType}})::Vector{DataType}
    all_deps = IdSet{DataType}()

    for p in data
        # Self-referential types depend on themselves
        delete!(p.second, p.first)
        # Add the dependcies to the set of all dependencies
        union!(all_deps, p.second)
    end

    # Any type that is present in the dependencies but not in `data` has no dependencies
    setdiff!(all_deps, keys(data))
    for ty in all_deps
        data[ty] = IdSet()
    end

    sorted = Vector{DataType}()
    sizehint!(sorted, length(data))

    types_without_deps = IdSet{DataType}()

    while true
        empty!(types_without_deps)

        # Find types with no remaining dependencies
        for (ty::DataType, deps) in data
            if isempty(deps)
                push!(types_without_deps, ty)
            end
        end

        # If there are no types without dependencies, we're done.
        if isempty(types_without_deps)
            break
        end

        # Add the types without dependencies to the list of results.
        append!(sorted, types_without_deps)

        # Remove types we've just added to `rst` from `data`
        filter!(data) do p
            retain = p.first ∉ types_without_deps
            # If the type is retained, remove types_without_deps from its deps
            retain && setdiff!(p.second, types_without_deps)
            retain
        end
    end

    @assert isempty(data) "a cyclic dependency exists amongst $(keys(data))"
    sorted
end

# The innermost `body` of a `UnionAll`
function partialtype(type::UnionAll)::DataType
    t = type

    while t.body isa UnionAll
        t = t.body
    end

    return t.body
end

# The type itself
function partialtype(type::DataType)::DataType
    return type
end

# The type with all its parameters erased
function basetype(type::DataType)::DataType
    definition = getproperty(type.name.module, type.name.name)
    partialtype(definition)
end

# The type with all its parameters erased, including those set on the innermost `body`.
function basetype(type::UnionAll)::DataType
    partial = partialtype(type)
    definition = getproperty(partial.name.module, partial.name.name)
    partialtype(definition)
end

# Populates `layouts` with layouts for all builtin types
function insertbuiltins!(layouts::IdDict{DataType,Layout})::Nothing
    layouts[UInt8] = BuiltinLayout("u8", [], false, false, false)
    layouts[UInt16] = BuiltinLayout("u16", [], false, false, false)
    layouts[UInt32] = BuiltinLayout("u32", [], false, false, false)
    layouts[UInt64] = BuiltinLayout("u64", [], false, false, false)
    layouts[Int8] = BuiltinLayout("i8", [], false, false, false)
    layouts[Int16] = BuiltinLayout("i16", [], false, false, false)
    layouts[Int32] = BuiltinLayout("i32", [], false, false, false)
    layouts[Int64] = BuiltinLayout("i64", [], false, false, false)

    layouts[Float32] = BuiltinLayout("f32", [], false, false, false)
    layouts[Float64] = BuiltinLayout("f64", [], false, false, false)
    layouts[Bool] = BuiltinLayout("::jlrs::data::layout::bool::Bool", [], false, false, false)
    layouts[Char] = BuiltinLayout("::jlrs::data::layout::char::Char", [], false, false, false)
    layouts[typeof(Union{})] = BuiltinLayout("::jlrs::data::layout::union::EmptyUnion", [], false, false, false)

    layouts[Any] = BuiltinLayout("::jlrs::data::managed::value::WeakValue", [], true, true, true)
    layouts[basetype(Array)] = BuiltinLayout("::jlrs::data::managed::array::WeakArray", [StructParameter(:T, true), StructParameter(:N, true)], true, true, true)
    layouts[DataType] = BuiltinLayout("::jlrs::data::managed::datatype::WeakDataType", [], true, false, true)
    layouts[Module] = BuiltinLayout("::jlrs::data::managed::module::WeakModule", [], true, false, true)
    layouts[Core.SimpleVector] = BuiltinLayout("::jlrs::data::managed::simple_vector::WeakSimpleVector", [], true, false, true)
    layouts[String] = BuiltinLayout("::jlrs::data::managed::string::WeakString", [], true, false, true)
    layouts[Symbol] = BuiltinLayout("::jlrs::data::managed::symbol::WeakSymbol", [], true, false, true)
    layouts[Core.TypeName] = BuiltinLayout("::jlrs::data::managed::type_name::WeakTypeName", [], true, false, true)
    layouts[TypeVar] = BuiltinLayout("::jlrs::data::managed::type_var::WeakTypeVar", [], true, false, true)
    layouts[Union] = BuiltinLayout("::jlrs::data::managed::union::WeakUnion", [], true, false, true)
    layouts[UnionAll] = BuiltinLayout("::jlrs::data::managed::union_all::WeakUnionAll", [], true, false, true)
    layouts[Expr] = BuiltinLayout("::jlrs::data::managed::expr::WeakExpr", [], true, false, true)

    layouts[Core.AbstractChar] = BuiltinAbstractLayout()
    layouts[Core.AbstractFloat] = BuiltinAbstractLayout()
    layouts[Core.AbstractString] = BuiltinAbstractLayout()
    layouts[Core.Exception] = BuiltinAbstractLayout()
    layouts[Core.Function] = BuiltinAbstractLayout()
    layouts[Core.IO] = BuiltinAbstractLayout()
    layouts[Core.Integer] = BuiltinAbstractLayout()
    layouts[Core.Number] = BuiltinAbstractLayout()
    layouts[Core.Real] = BuiltinAbstractLayout()
    layouts[Core.Signed] = BuiltinAbstractLayout()
    layouts[Core.Unsigned] = BuiltinAbstractLayout()

    layouts[Base.AbstractDisplay] = BuiltinAbstractLayout()
    layouts[Base.AbstractIrrational] = BuiltinAbstractLayout()
    layouts[Base.AbstractMatch] = BuiltinAbstractLayout()
    layouts[Base.AbstractPattern] = BuiltinAbstractLayout()
    layouts[Base.IndexStyle] = BuiltinAbstractLayout()

    layouts[basetype(Core.AbstractArray)] = BuiltinAbstractLayout()
    layouts[basetype(Core.DenseArray)] = BuiltinAbstractLayout()
    layouts[basetype(Core.Ref)] = BuiltinAbstractLayout()
    layouts[basetype(Core.Type)] = BuiltinAbstractLayout()

    layouts[basetype(Base.AbstractChannel)] = BuiltinAbstractLayout()
    layouts[basetype(Base.AbstractDict)] = BuiltinAbstractLayout()
    layouts[basetype(Base.AbstractMatrix)] = BuiltinAbstractLayout()
    layouts[basetype(Base.AbstractRange)] = BuiltinAbstractLayout()
    layouts[basetype(Base.AbstractSet)] = BuiltinAbstractLayout()
    if isdefined(Base, :AbstractSlices)
        layouts[basetype(Base.AbstractSlices)] = BuiltinAbstractLayout()
    end
    layouts[basetype(Base.AbstractUnitRange)] = BuiltinAbstractLayout()
    layouts[basetype(Base.AbstractVector)] = BuiltinAbstractLayout()
    layouts[basetype(Base.DenseMatrix)] = BuiltinAbstractLayout()
    layouts[basetype(Base.DenseVector)] = BuiltinAbstractLayout()
    layouts[basetype(Base.Enum)] = BuiltinAbstractLayout()
    layouts[basetype(Base.OrdinalRange)] = BuiltinAbstractLayout()

    nothing
end

# Returns `true` if the union type has no unset type parameters.
function isnonparametric(type::Union)::Bool
    for utype in Base.uniontypes(type)
        # TODO: UnionAll?
        if utype isa DataType
            !isnothing(findfirst(p -> p isa TypeVar, utype.parameters)) && return false
            continue
        elseif utype isa TypeVar
            return false
        end
    end

    true
end

function is_pointer_free_type(ty, env)
    if !isdefined(ty, :types)
        return true
    end

    for ty in ty.types
        if ty isa DataType
            if ismutabletype(ty)
                return false
            elseif isabstracttype(ty)
                return false
            else
                if !has_pointer_free_partialtype(ty, env)
                    return false
                end
            end
        elseif ty isa Union
            return false
        elseif ty isa UnionAll
            ty2 = ty
            while ty2 isa UnionAll
                if ty2.var ∉ env
                    return false
                end

                ty2 = ty2.body
            end

            if isabstracttype(ty)
                return false
            elseif !has_pointer_free_partialtype(ty, env)
                return false
            end
        end
    end

    true
end

function has_pointer_free_basetype(ty)
    basety = basetype(ty)
    env = Set(basety.parameters)
    is_pointer_free_type(basety, env)
end

function has_pointer_free_partialtype(ty, env)
    partialty = partialtype(ty)
    is_pointer_free_type(partialty, env)
end

function extracttupledeps_notconcrete!(acc::IdDict{DataType,IdSet{DataType}}, type::DataType, layouts::IdDict{DataType,Layout})::Nothing
    for ttype in type.types
        extractdeps!(acc, ttype, layouts)
    end

    nothing
end

function extracttupledeps!(acc::IdDict{DataType,IdSet{DataType}}, key::DataType, type::DataType, layouts::IdDict{DataType,Layout})::Nothing
    for ttype in type.types
        if ttype isa DataType
            if ttype <: Tuple
                if !isconcretetype(ttype)
                    extracttupledeps_notconcrete!(acc, ttype, layouts)
                else
                    extracttupledeps!(acc, key, ttype, layouts)
                end
            else
                tbase = basetype(ttype)
                push!(acc[key], tbase)
                extractdeps!(acc, ttype, layouts)
            end
        elseif ttype isa Union
            extractdeps!(acc, ttype, layouts)
        end
    end

    nothing
end

# Returns `true` if the type has atomic fields
function hasatomicfields(type::DataType)::Bool
    if hasproperty(type.name, :atomicfields)
        return type.name.atomicfields != C_NULL
    end

    false
end

function extractdeps!(acc::IdDict{DataType,IdSet{DataType}}, @nospecialize(type::Type), layouts::IdDict{DataType,Layout})::Nothing
    if type isa DataType
        if type <: Tuple
            return extracttupledeps_notconcrete!(acc, type, layouts)
        end

        partial = partialtype(type)
        base = basetype(type)

        if (base in keys(layouts)) && layouts[base] isa UnsupportedLayout
            error(layouts[base].reason)
        end

        if !(base in keys(acc)) && !(base in keys(layouts))
            acc[base] = IdSet()

            for btype in base.types
                if btype isa DataType
                    if ismutabletype(btype)
                        continue
                    end

                    if btype <: Tuple
                        if findfirst(btype.parameters) do p
                            p isa TypeVar
                        end !== nothing
                            error("Tuple fields with type parameters are not supported")
                        elseif !isconcretetype(btype)
                            extracttupledeps_notconcrete!(acc, btype, layouts)
                        else
                            extracttupledeps!(acc, type, btype, layouts)
                        end
                    else
                        bbase = basetype(btype)
                        push!(acc[base], bbase)
                        extractdeps!(acc, btype, layouts)
                    end
                elseif btype isa UnionAll
                    continue
                elseif btype isa Union
                    if !isnonparametric(btype)
                        error("Unions with type parameters are not supported")
                    end

                    if Base.isbitsunion(btype)
                        extractdeps!(acc, btype, layouts)
                    end
                end
            end
        end

        btypes = base.parameters
        ptypes = partial.parameters

        for i in eachindex(btypes)
            btype = btypes[i]
            ptype = ptypes[i]
            if btype isa TypeVar && ptype isa Type
                extractdeps!(acc, ptype, layouts)
            end
        end
    elseif type isa UnionAll
        extractdeps!(acc, partialtype(type), layouts)
    elseif type isa Union
        for uniontype in Base.uniontypes(type)
            if uniontype isa TypeVar
                error("Unions with type parameters are not supported")
            end

            extractdeps!(acc, uniontype, layouts)
        end
    end

    nothing
end

function extractparams(@nospecialize(ty::Type), layouts::IdDict{DataType,Layout})::IdSet{TypeVar}
    out = IdSet()
    if ty <: Tuple
        for elty in ty.parameters
            union!(out, extractparams(elty, layouts))
        end

        return out
    elseif ty isa Union
        return out
    end

    partial = partialtype(ty)
    base = basetype(ty)

    layout = layouts[base]

    if !hasproperty(partial, :parameters)
        return out
    end

    for (name, param) in zip(layout.typeparams, partial.parameters)
        if !name.elide
            if param isa TypeVar
                idx = findfirst(t -> t.name == name.name, layout.typeparams)
                if idx !== nothing
                    push!(out, param)
                end
            elseif param isa Type
                union!(out, extractparams(param, layouts))
            end
        end
    end

    out
end

function concretetuplefield(@nospecialize(tuple::Type), layouts::IdDict{DataType,Layout})::TupleLayout
    scopelifetime = false
    datalifetime = false
    fieldlayouts::Vector{TupleField} = []

    for ty in tuple.types
        fieldlayout = if ty isa DataType
            if Base.uniontype_layout(ty)[1]
                if ty <: Tuple
                    b = concretetuplefield(ty, layouts)
                    scopelifetime |= b.scopelifetime
                    datalifetime |= b.datalifetime
                    TupleField(b, [], b.scopelifetime, b.datalifetime)
                else
                    bty = basetype(ty)
                    b = layouts[bty]
                    tparams = map(a -> TypeParameter(a[1].name, a[2]), zip(bty.parameters, ty.parameters))
                    scopelifetime |= b.scopelifetime
                    datalifetime |= b.datalifetime
                    TupleField(b, tparams, b.scopelifetime, b.datalifetime)
                end
            elseif ty in keys(layouts)
                b = layouts[ty]
                if b isa BuiltinLayout
                    scopelifetime |= b.scopelifetime
                    datalifetime |= b.datalifetime
                    TupleField(b, [], b.scopelifetime, b.datalifetime)
                else
                    scopelifetime = true
                    datalifetime = true
                    TupleField(layouts[Any], [], true, true)
                end
            else
                scopelifetime = true
                datalifetime = true
                TupleField(layouts[Any], [], true, true)
            end
        else
            error("Invalid type")
        end

        push!(fieldlayouts, fieldlayout)
    end

    TupleLayout(fieldlayouts, scopelifetime, datalifetime)
end


function structfield(fieldname::Symbol, @nospecialize(fieldtype::Union{Type,TypeVar}), layouts::IdDict{DataType,Layout})::StructField
    if fieldtype isa TypeVar
        StructField(fieldname, string(fieldname), GenericLayout(fieldtype.name), [TypeParameter(fieldtype.name, fieldtype)], IdSet{TypeVar}([fieldtype]), false, false, false)
    elseif fieldtype isa UnionAll
        bt = basetype(fieldtype)

        if bt isa Union
            error("Unions with type parameters are not supported")
        elseif bt.name.name == :Array
            fieldlayout = layouts[bt]
            tparams = map(a -> TypeParameter(a[1].name, a[2]), zip(bt.parameters, bt.parameters))
            references = extractparams(bt, layouts)
            StructField(fieldname, string(fieldname), fieldlayout, tparams, references, fieldlayout.scopelifetime, fieldlayout.datalifetime, false)
        else
            StructField(fieldname, string(fieldname), layouts[Any], [], IdSet(), true, true, false)
        end
    elseif fieldtype isa Union
        if Base.isbitsunion(fieldtype)
            StructField(fieldname, string(fieldname), BitsUnionLayout(fieldtype), [], IdSet(), false, false, false)
        else
            StructField(fieldname, string(fieldname), layouts[Any], [], IdSet(), true, true, false)
        end
    elseif fieldtype == Union{}
        StructField(fieldname, string(fieldname), layouts[Union{}], [], IdSet(), false, false, false)
    elseif fieldtype <: Tuple
        params = extractparams(fieldtype, layouts)
        if length(params) > 0
            error("Tuples with type parameters are not supported")
        elseif isconcretetype(fieldtype)
            layout = concretetuplefield(fieldtype, layouts)
            StructField(fieldname, string(fieldname), layout, [], IdSet(), layout.scopelifetime, layout.datalifetime, false)
        else
            StructField(fieldname, string(fieldname), layouts[Any], [], IdSet(), true, true, false)
        end
    elseif fieldtype isa DataType
        bt = basetype(fieldtype)
        if bt in keys(layouts)
            fieldlayout = layouts[bt]
            if fieldlayout isa StructLayout && ismutabletype(fieldtype)
                StructField(fieldname, string(fieldname), layouts[Any], [], IdSet(), true, true, false)
            elseif fieldlayout isa AbstractTypeLayout || fieldlayout isa BuiltinAbstractLayout
                StructField(fieldname, string(fieldname), layouts[Any], [], IdSet(), true, true, false)
            else
                tparams = map(a -> TypeParameter(a[1].name, a[2]), zip(bt.parameters, fieldtype.parameters))
                references = extractparams(fieldtype, layouts)
                StructField(fieldname, string(fieldname), fieldlayout, tparams, references, fieldlayout.scopelifetime, fieldlayout.datalifetime, false)
            end
        elseif ismutabletype(fieldtype)
            StructField(fieldname, string(fieldname), layouts[Any], [], IdSet(), true, true, false)
        elseif Base.uniontype_layout(fieldtype)[1]
            StructField(fieldname, string(fieldname), layouts[Any], [], IdSet(), true, true, false)
        else
            error("Cannot create field layout for $bt")
        end
    else
        error("Unknown field type")
    end
end

function isenumtype(ty::DataType)
    ty <: Enum
end

function createlayout!(layouts::IdDict{DataType,Layout}, @nospecialize(type::Type))::Nothing
    bt::DataType = basetype(type)

    if bt in keys(layouts)
        return
    end

    if hasatomicfields(bt)
        params = map(a -> StructParameter(a.name, true), bt.parameters)
        layouts[bt] = ContainsAtomicFieldsLayout(type.name.name, type.name, type, string(type.name.name), "", params)
        return
    end

    if isabstracttype(bt)
        params = map(a -> StructParameter(a.name, true), bt.parameters)
        layouts[bt] = AbstractTypeLayout(type.name.name, type.name, type, string(type.name.name), "", params)
        return
    end

    if isenumtype(bt)
        repr = bt.super.parameters[1]
        if !(repr in (Int8, Int16, Int32, Int64, Int, UInt8, UInt16, UInt32, UInt64, UInt))
            error("Enum type must be one of: Int8, Int16, Int32, Int64, Int, UInt8, UInt16, UInt32, UInt64, UInt. Enum type of $(bt) is $(repr)")
        end
        variants = [map(i -> EnumVariant(Symbol(string(i)), string(i), i), instances(bt))...]
        layouts[bt] = EnumLayout(bt.name.name, bt, string(type.name.name), "", variants)
        return
    end

    fields = []
    typevars = IdSet()
    scopelifetime = false
    datalifetime = false

    for (name, ty) in zip(fieldnames(bt), fieldtypes(bt))
        field = structfield(name, ty, layouts)
        scopelifetime |= field.scopelifetime
        datalifetime |= field.datalifetime
        union!(typevars, field.referenced)
        push!(fields, field)
    end

    params = map(a -> StructParameter(a.name, !(a in typevars)), bt.parameters)
    layouts[bt] = StructLayout(type.name.name, type.name, type, string(type.name.name), "", fields, params, scopelifetime, datalifetime)

    nothing
end

function haslifetimes(@nospecialize(ty::Type), layouts::IdDict{DataType,Layout})::Tuple{Bool,Bool}
    scopelifetime = false

    if ty <: Tuple
        if isconcretetype(ty)
            for fty in ty.types
                scopelt, datalt = haslifetimes(fty, layouts)
                if datalt
                    return (true, true)
                end

                scopelifetime |= scopelt
            end
        else
            return (true, true)
        end
    else
        bt = basetype(ty)
        layout = layouts[bt]

        if layout.datalifetime
            return (true, true)
        end

        scopelifetime |= layout.scopelifetime

        if layout isa StructLayout

            for param in ty.parameters
                if param isa Type
                    scopelt, datalt = haslifetimes(param, layouts)
                    if datalt
                        return (true, true)
                    end

                    scopelifetime |= scopelt
                end
            end
        end
    end

    (scopelifetime, false)
end

function propagate_internal_param_lifetimes!(layouts::IdDict{DataType,Layout})::Nothing
    for (_, layout) in layouts
        if layout isa StructLayout
            scopelifetime = layout.scopelifetime
            datalifetime = layout.datalifetime

            if datalifetime
                continue
            end

            for field in layout.fields, param in field.typeparams
                if param.value !== nothing && !(param.value isa TypeVar)
                    scopelt, datalt = haslifetimes(param.value, layouts)
                    if datalt
                        scopelifetime = true
                        datalifetime = true
                        break
                    end

                    scopelifetime |= scopelt
                end
            end

            layout.scopelifetime = scopelifetime
            layout.datalifetime = datalifetime
        end
    end

    nothing
end


function strgenerics(layout::StructLayout)::Union{Nothing,String}
    generics = []

    if layout.scopelifetime
        push!(generics, "'scope")
    end

    if layout.datalifetime
        push!(generics, "'data")
    end

    for param in layout.typeparams
        if !param.elide
            push!(generics, string(param.name))
        end
    end

    if length(generics) > 0
        "<$(join(generics, ", "))>"
    end
end

function strsignature(ty::DataType, layouts::IdDict{DataType,Layout})::String
    if ty <: Tuple
        generics = []

        for ty in ty.types
            push!(generics, strsignature(ty, layouts))
        end

        name = "::jlrs::data::layout::tuple::Tuple$(length(generics))"

        if length(generics) > 0
            return "$(name)<$(join(generics, ", "))>"
        else
            return name
        end
    end

    base = basetype(ty)
    layout = layouts[base]

    name = layout.rsname
    wrap_opt = false
    if layout isa BuiltinLayout && layout.pointerfield
        wrap_opt = true
    end

    generics = []
    if layout.scopelifetime
        push!(generics, "'scope")
    end

    if layout.datalifetime
        push!(generics, "'data")
    end

    for (tparam, param) in zip(layout.typeparams, ty.parameters)
        if !tparam.elide
            if param isa TypeVar
                idx = findfirst(a -> a.name == param.name, layout.typeparams)
                if idx !== nothing
                    push!(generics, string(param.name))
                end
            elseif param isa DataType
                push!(generics, strsignature(param, layouts))
            end
        end
    end

    name = if length(generics) > 0
        "$(name)<$(join(generics, ", "))>"
    else
        name
    end

    if wrap_opt
        "::std::option::Option<$name>"
    else
        name
    end
end

function strsignature(layout::StructLayout, field::Union{StructField,TupleField}, layouts::IdDict{DataType,Layout})::String
    wrap_opt = false

    if field isa StructField && field.fieldtype isa StructLayout && ismutabletype(field.fieldtype.type)
        return "::std::option::Option<::jlrs::data::managed::value::WeakValue<'scope, 'data>>"
    end

    if field.fieldtype isa GenericLayout
        return string(field.fieldtype.name)
    elseif field.fieldtype isa TupleLayout
        return strtuplesignature(layout, field, layouts)
    elseif field.fieldtype isa BuiltinLayout && field.fieldtype.pointerfield
        wrap_opt = true
    end

    generics = []
    if field.scopelifetime
        push!(generics, "'scope")
    end

    if field.datalifetime
        push!(generics, "'data")
    end

    for (sparam, tparam) in zip(field.fieldtype.typeparams, field.typeparams)
        if !sparam.elide
            if tparam.value isa TypeVar
                idx = findfirst(a -> a.name == tparam.value.name, layout.typeparams)
                if idx !== nothing
                    push!(generics, string(tparam.value.name))
                end
            elseif tparam.value isa DataType
                push!(generics, strsignature(tparam.value, layouts))
            end
        end
    end

    n = if length(generics) > 0
        "$(field.fieldtype.rsname)<$(join(generics, ", "))>"
    else
        field.fieldtype.rsname
    end

    if wrap_opt
        "::std::option::Option<$n>"
    else
        n
    end
end

function strtuplesignature(layout::StructLayout, field::Union{StructField,TupleField}, layouts::IdDict{DataType,Layout})::String
    generics = []

    for fieldlayout in field.fieldtype.fields
        push!(generics, strsignature(layout, fieldlayout, layouts))
    end

    if length(generics) > 0
        "$(field.fieldtype.rsname)<$(join(generics, ", "))>"
    else
        field.fieldtype.rsname
    end
end

function strstructname(layout::StructLayout)::String
    generics = strgenerics(layout)
    if generics !== nothing
        "$(layout.rsname)$(generics)"
    else
        "$(layout.rsname)"
    end
end

function flatten_union!(acc::Vector{DataType}, l::Union, r::Union)
    flatten_union!(acc, l.a, l.b)
    flatten_union!(acc, r.a, r.b)
end

function flatten_union!(acc::Vector{DataType}, l::Union, r::DataType)
    flatten_union!(acc, l.a, l.b)
    push!(acc, r)
end

function flatten_union!(acc::Vector{DataType}, l::DataType, r::Union)
    push!(acc, l)
    flatten_union!(acc, r.a, r.b)
end

function flatten_union!(acc::Vector{DataType}, l::DataType, r::DataType)
    push!(acc, l)
    push!(acc, r)
end

function flatten_union(u::Union)
    flattened = Vector{DataType}()
    flatten_union!(flattened, u.a, u.b)
    flattened
end

"""
    constant_type_var(t)::String

When the field of a struct is a union of isbits types, its type in Rust can be annotated with its
variant types. In Julia, instances of isbits types can be used as type variables, but Rust only
supports a small number of primitive types. In the rare case that you're trying to generate a
layout for a struct that contains a bits union with such a non-primitive isbits type variable,
you will need to provide a custom implementation of `ConstructType` in Rust and extend this
function in Julia to provide a mapping.
"""
function constant_type_var(t)
    throw(ErrorException("custom_constant(t) has not been implemented for $(typeof(t))"))
end

constant_type_var(value::Int64) = "::jlrs::data::types::construct_type::ConstantI64<$value>"
constant_type_var(value::Int32) = "::jlrs::data::types::construct_type::ConstantI32<$value>"
constant_type_var(value::Int16) = "::jlrs::data::types::construct_type::ConstantI16<$value>"
constant_type_var(value::Int8) = "::jlrs::data::types::construct_type::ConstantI8<$value>"
constant_type_var(value::UInt64) = "::jlrs::data::types::construct_type::ConstantU64<$value>"
constant_type_var(value::UInt32) = "::jlrs::data::types::construct_type::ConstantU32<$value>"
constant_type_var(value::UInt16) = "::jlrs::data::types::construct_type::ConstantU16<$value>"
constant_type_var(value::UInt8) = "::jlrs::data::types::construct_type::ConstantU8<$value>"
constant_type_var(value::Bool) = "::jlrs::data::types::construct_type::ConstantBool<$value>"

function qualified_type(value, layouts::IdDict{DataType,Layout})
    constant_type_var(value)
end

function qualified_type(ty::Type{T}, layouts::IdDict{DataType,Layout}) where {T <: Tuple}
    generics = []

    for ty in ty.types
        push!(generics, qualified_type(ty, layouts))
    end

    name = "::jlrs::data::layout::tuple::Tuple$(length(generics))"

    if length(generics) > 0
        return "$(name)<$(join(generics, ", "))>"
    else
        return name
    end
end

function qualified_type(ty::DataType, layouts::IdDict{DataType,Layout})
    base = basetype(ty)
    layout = layouts[base]
    name = layout.rsname

    generics = []
    use_ctor = false

    for (tparam, param) in zip(layout.typeparams, ty.parameters)
        use_ctor |= tparam.elide
        if param isa TypeVar
            idx = findfirst(a -> a.name == param.name, layout.typeparams)
            if idx !== nothing
                push!(generics, string(param.name))
            end
        elseif param isa DataType
            push!(generics, qualified_type(param, layouts))
        elseif tparam.elide
            push!(generics, qualified_type(param, layouts))
        end
    end

    if use_ctor
        if length(generics) > 0
            "$(name)TypeConstructor<$(join(generics, ", "))>"
        else
            "$(name)TypeConstructor"
        end
    else
        if length(generics) > 0
            "$(name)<$(join(generics, ", "))>"
        else
            name
        end
    end
end

function bitsunion_type_constructor(union_of::Union, layouts::IdDict{DataType,Layout})
    flattened = flatten_union(union_of)
    field_types = Vector{String}()
    for ty in flattened
        push!(field_types, qualified_type(ty, layouts))
    end

    "::jlrs::UnionOf![$(join(field_types, ", "))]"
end

function structfield_parts(layout::StructLayout, field::StructField, layouts::IdDict{DataType,Layout}, typed_bits_union::Bool)::Vector{String}
    parts = Vector{String}()
    if field.fieldtype isa BitsUnionLayout
        align_field_name = "_$(field.rsname)_align"
        flag_field_name = "$(field.rsname)_flag"

        is_bits_union, size, align = Base.uniontype_layout(field.fieldtype.union_of)
        @assert is_bits_union "Not a bits union. This should never happen, please file a bug report."

        alignment_ty = if align == 1
            "::jlrs::data::layout::union::Align1"
        elseif align == 2
            "::jlrs::data::layout::union::Align2"
        elseif align == 4
            "::jlrs::data::layout::union::Align4"
        elseif align == 8
            "::jlrs::data::layout::union::Align8"
        elseif align == 16
            "::jlrs::data::layout::union::Align16"
        else
            error("Unsupported alignment")
        end

        push!(parts, "#[jlrs(bits_union_align)]")
        push!(parts, "$(align_field_name): $(alignment_ty),")
        push!(parts, "#[jlrs(bits_union)]")
        if typed_bits_union
            type_ctor = bitsunion_type_constructor(field.fieldtype.union_of, layouts)
            push!(parts, "pub $(field.rsname): ::jlrs::data::layout::union::TypedBitsUnion<$type_ctor, $size>,")
        else
            push!(parts, "pub $(field.rsname): ::jlrs::data::layout::union::BitsUnion<$size>,")
        end
        push!(parts, "#[jlrs(bits_union_flag)]")
        push!(parts, "pub $(flag_field_name): u8,")
    else
        sig = strsignature(layout, field, layouts)
        push!(parts, "pub $(field.rsname): $(sig),")
    end

    parts
end

function filteredname(mod::Module)::Vector{String}
    parts = Vector{String}()
    for part in fullname(mod)
        s_part = string(part);

        if !startswith(s_part, "__doctest")
            push!(parts, s_part)
        end
    end

    parts
end

strlayout(::BuiltinLayout, ::IdDict{DataType,Layout}, ::Bool)::Union{Nothing,String} = nothing
strlayout(::UnsupportedLayout, ::IdDict{DataType,Layout}, ::Bool)::Union{Nothing,String} = nothing
strlayout(::BuiltinAbstractLayout, ::IdDict{DataType,Layout}, ::Bool)::Union{Nothing,String} = nothing

function strlayout(layout::AbstractTypeLayout, ::IdDict{DataType,Layout}, ::Bool)::Union{Nothing,String}
    typepath = string(layout.path)
    if length(typepath) == 0
        modulepath = join(filteredname(layout.typename.module), ".")
        typepath = "$(modulepath).$(layout.typename.name)"
    end

    parts = []

    # A separate type constructor is needed due to the presence of elided parameters.
    param_names = map(param -> string(param.name), layout.typeparams)

    push!(parts, "#[derive(ConstructType)]")
    push!(parts, "#[jlrs(julia_type = \"$(typepath)\")]")
    if length(param_names) == 0
        push!(parts, "pub struct $(layout.rsname) {")
    else
        push!(parts, "pub struct $(layout.rsname)<$(join(param_names, ", "))> {")
        for param in param_names
            push!(parts, "    _$(lowercase(param)): ::std::marker::PhantomData<$(param)>,")
        end
    end
    push!(parts, "}")

    join(parts, "\n")
end

function strlayout(layout::ContainsAtomicFieldsLayout, ::IdDict{DataType,Layout}, ::Bool)::Union{Nothing,String}
    typepath = string(layout.path)
    if length(typepath) == 0
        modulepath = join(filteredname(layout.typename.module), ".")
        typepath = "$(modulepath).$(layout.typename.name)"
    end

    parts = []

    # A separate type constructor is needed due to the presence of elided parameters.
    param_names = map(param -> string(param.name), layout.typeparams)

    push!(parts, "#[derive(ConstructType)]")
    push!(parts, "#[jlrs(julia_type = \"$(typepath)\")]")
    if length(param_names) == 0
        push!(parts, "pub struct $(layout.rsname)TypeConstructor {")
    else
        push!(parts, "pub struct $(layout.rsname)TypeConstructor<$(join(param_names, ", "))> {")
        for param in param_names
            push!(parts, "    _$(lowercase(param)): ::std::marker::PhantomData<$(param)>,")
        end
    end
    push!(parts, "}")

    join(parts, "\n")
end

function strlayout(layout::EnumLayout, layouts::IdDict{DataType,Layout}, ::Bool)::Union{Nothing,String}
    repr = layout.type.super.parameters[1]
    repr_rsname = layouts[repr].rsname

    typepath = string(layout.path)
    modulepath = if length(typepath) == 0
        modulepath = join(filteredname(layout.type.name.module), '.')
        typepath = "$(modulepath).$(layout.type.name.name)"
        modulepath
    else
        split_name = split(typepath, '.')
        pop!(split_name)
        join(split_name, '.')
    end

    parts = []

    push!(
        parts,
        "#[repr($repr_rsname)]",
        "#[jlrs(julia_type = \"$(typepath)\")]",
        "#[derive(Copy, Clone, Debug, PartialEq, Enum, Unbox, IntoJulia, ConstructType, IsBits, Typecheck, ValidField, ValidLayout, CCallArg, CCallReturn)]",
        "enum $(layout.rsname) {"
    )

    for variant in layout.fields
        push!(
            parts,
            "    #[allow(non_camel_case_types)]",
            "    #[jlrs(julia_enum_variant = \"$(modulepath).$(variant.name)\")]",
            "    $(variant.rsname) = $(repr(variant.value)),"
        )
    end

    push!(parts, "}")

    join(parts, "\n")
end

function strlayout(layout::StructLayout, layouts::IdDict{DataType,Layout}, typed_bits_union::Bool)::Union{Nothing,String}
    ty = getproperty(layout.typename.module, layout.typename.name)

    is_parameter_free = ty isa DataType && isnothing(findfirst(p -> p isa TypeVar, ty.parameters))
    into_julia = is_parameter_free && isbitstype(ty)
    is_bits = has_pointer_free_basetype(ty)
    is_zst = into_julia && sizeof(ty) == 0
    is_mut = ismutabletype(basetype(ty))
    is_constructible = isnothing(findfirst(x -> x.elide == true, layout.typeparams))

    traits = ["Clone", "Debug", "Unbox", "ValidLayout", "Typecheck"]
    into_julia && push!(traits, "IntoJulia")
    is_mut || push!(traits, "ValidField")
    !is_mut && is_bits && push!(traits, "IsBits")
    is_constructible && push!(traits, "ConstructType")
    is_constructible && !is_zst && !is_mut && push!(traits, "CCallArg")

    # TODO: Are zero-sized types valid return types? `Nothing` is, are others?
    # What about bits types with elided parameters?
    is_constructible && !is_zst && !is_mut && is_bits && push!(traits, "CCallReturn")

    typepath = string(layout.path)
    if length(typepath) == 0
        modulepath = join(filteredname(layout.typename.module), ".")
        typepath = "$(modulepath).$(layout.typename.name)"
    end

    typepath_annotation = "julia_type = \"$(typepath)\""

    annotations = Vector{String}()
    push!(annotations, typepath_annotation)
    is_zst && push!(annotations, "zero_sized_type")

    parts = [
        "#[repr(C)]",
        "#[derive($(join(traits, ", ")))]",
        "#[jlrs($(join(annotations, ", ")))]",
        "pub struct $(strstructname(layout)) {"
    ]
    for field in layout.fields
        for part in structfield_parts(layout, field, layouts, typed_bits_union)
            push!(parts, "    $(part)")
        end
    end
    push!(parts, "}")

    if !is_constructible
        # A separate type constructor is needed due to the presence of elided parameters.

        elided_param_names = map(filter(layout.typeparams) do x x.elide end) do x string(x.name) end
        if isempty(elided_param_names)
            elided_param_names = "[]"
        end

        unelided_param_names = map(filter(layout.typeparams) do x !x.elide end) do x string(x.name) end
        if isempty(unelided_param_names)
            unelided_param_names = "[]"
        end

        param_names = map(param -> string(param.name), layout.typeparams)
        if isempty(param_names)
            param_names = "[]"
        end

        generics = strgenerics(layout)
        if isnothing(generics)
            generics = ""
        end

        attrs = "#[jlrs($(typepath_annotation), constructor_for = \"$(layout.rsname)\", scope_lifetime = $(layout.scopelifetime), data_lifetime = $(layout.datalifetime), layout_params = $(unelided_param_names), elided_params = $(elided_param_names), all_params = $(param_names))]"

        push!(parts, "")
        push!(parts, "#[derive(ConstructType, HasLayout)]")
        push!(parts, attrs)
        push!(parts, "pub struct $(layout.rsname)TypeConstructor<$(join(param_names, ", "))> {")
        for param in param_names
            push!(parts, "    _$(lowercase(param)): ::std::marker::PhantomData<$(param)>,")
        end
        push!(parts, "}")
    end

    join(parts, "\n")
end
end
