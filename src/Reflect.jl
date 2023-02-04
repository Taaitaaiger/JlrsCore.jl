module Reflect
using Base.Experimental
export reflect, renamestruct!, renamefields!, overridepath!
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
    referenced::Set{TypeVar}
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
    TupleLayout(fields::Vector{TupleField}, scopelifetime::Bool, datalifetime::Bool) = new(string("::jlrs::data::layout::tuple::Tuple", length(fields)), fields, scopelifetime, datalifetime)
end

struct BuiltinLayout <: Layout
    rsname::String
    typeparams::Vector{StructParameter}
    scopelifetime::Bool
    datalifetime::Bool
    pointerfield::Bool
end

struct BuiltinAbstractLayout <: Layout
end

struct UnsupportedLayout <: Layout
    reason::String
end

struct Layouts
    dict::Dict{Type,Layout}
end

struct StringLayouts
    dict::Dict{Type,String}
end

"""
    reflect(types::Vector{<:Type}; f16::Bool=false, internaltypes::Bool=false)::Layouts

Generate Rust layouts and type constructors for all types in `types` and their dependencies. The
only requirement is that these types must not contain any union or tuple fields that directly
depend on a type parameter.

A layout is a Rust type whose layout exactly matches the layout of the Julia type it's reflected
from. Layous are generated for the most general case by erasing the content of all provided type
parameters, so you can't avoid the restrictions regarding union and tuple fields with type
parameters by explicitly providing a more qualified type. The only effect qualifying types has, is
that layouts for the used parameters will also be generated. If a type parameter doesn't affect
its layout it's elided from the generated layout.

Layouts automatically derive a bunch of traits to enable using them with jlrs. The following
traits will be implemented as long as their requirements are met:

- `Clone` and `Debug` are always derived.

- `ValidLayout` is always derived, enables checking if the layout of a Julia type is compatible
  with that Rust type.

- `Typecheck` is always derived, calls `ValidLayout::valid_layout`.

- `Unbox` is always derived, enables converting Julia data to an instance of this type by casting
  and dereferencing the internal pointer of a `Value`.

- `ValidField` is derived if this type is stored inline when used as a field type, which is
  generally the case if the Julia type is immutable and concrete. `ValidLayout` and `ValidField`
  are implemented by calling `ValidField::valid_field` for each field.

- `IntoJulia` is derived if the type is an isbits type with no type parameters, enables converting
  data of that type directly to a `Value` with `Value::new`.

- `ConstructType` is derived if no type parameters have been elided, if it does have elided
  parameters, a zero-sized struct named `{type_name}TypeConstructor` is generated which elides no
  parameters and derives nothing but this trait. This trait enables the Julia type associated with
  the Rust type to be constructed without depending on any existing data.

- `CCallArg` and `CCallReturn` are derived if the type is immutable, these types can be used in
  argument and return positions with Rust functions that are called from Julia through `ccall`.

Some types are only available in jlrs if the `internal-types` feature is enabled, if you've
enabled this feature you can set the `internaltypes` keyword argument to `true` to make use of
these provided layouts in the unlikely case that the types you're reflecting depend on them.
Similarly, the `Float16` type can only be reflected when the `f16` feature is enabled in jlrs and
the `f16` keyword argument is set to `true`.

The result of this function can be written to a file, its contents will normally be a valid Rust
module.

When you use these layouts with jlrs, these types must be available with the same path. For
example, if you generate layouts for `Main.Bar.Baz`, this type must be available through that
exact path and not some other path like `Main.Foo.Bar.Baz`. The path can be overriden by calling
`overridepath!`.

# Example
```jldoctest
julia> using Jlrs.Reflect

julia> reflect([Complex])
#[repr(C)]
#[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
#[jlrs(julia_type = "Base.Complex")]
pub struct Complex<T> {
    pub re: T,
    pub im: T,
}
```
"""
function reflect(types::Vector{<:Type}; f16::Bool=false, internaltypes::Bool=false)::Layouts
    deps = Dict{DataType,Set{DataType}}()
    layouts = Dict{Type,Layout}()
    insertbuiltins!(layouts; f16, internaltypes)

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
    Layouts(layouts)
end

"""
    renamestruct!(layouts::Layouts, type::Type, rename::String)

Change a struct's name. This can be useful if the name of a struct results in invalid Rust code or
causes warnings.

# Example
```jldoctest
julia> using Jlrs.Reflect

julia> struct Foo end

julia> layouts = reflect([Foo]);

julia> renamestruct!(layouts, Foo, "Bar")

julia> layouts
#[repr(C)]
#[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, ConstructType)]
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
julia> using Jlrs.Reflect

julia> struct Food burger::Bool end

julia> layouts = reflect([Food]);

julia> renamefields!(layouts, Food, [:burger => "hamburger"])

julia> layouts
#[repr(C)]
#[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, ConstructType, CCallArg, CCallReturn)]
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
julia> using Jlrs.Reflect

julia> struct Foo end

julia> layouts = reflect([Foo]);

julia> overridepath!(layouts, Foo, "Main.A.Bar")

julia> layouts
#[repr(C)]
#[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, ConstructType)]
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

function StringLayouts(layouts::Layouts)
    strlayouts = Dict{Type,String}()

    for name in keys(layouts.dict)
        rustimpl = strlayout(layouts.dict[name], layouts.dict)
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
        rustimpl = strlayout(layouts.dict[name], layouts.dict)
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
        rustimpl = strlayout(layouts.dict[name], layouts.dict)
        if rustimpl !== nothing
            push!(rustimpls, rustimpl)
        end
    end

    write(io, join(rustimpls, "\n\n"))
end

function toposort!(data::Dict{DataType,Set{DataType}})::Vector{Type}
    for (k, v) in data
        delete!(v, k)
    end

    for item in setdiff(reduce(∪, values(data)), keys(data))
        data[item] = Set()
    end

    rst = Vector()
    while true
        ordered = Set(item for (item, dep) in data if isempty(dep))
        if isempty(ordered)
            break
        end
        append!(rst, ordered)
        data = Dict(item => setdiff(dep, ordered) for (item, dep) in data if item ∉ ordered)
    end

    @assert isempty(data) "a cyclic dependency exists amongst $(keys(data))"
    rst
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

# Populates `BUILTINS`
function insertbuiltins!(layouts::Dict{Type,Layout}; f16::Bool=false, internaltypes::Bool=false)::Nothing
    layouts[UInt8] = BuiltinLayout("u8", [], false, false, false)
    layouts[UInt16] = BuiltinLayout("u16", [], false, false, false)
    layouts[UInt32] = BuiltinLayout("u32", [], false, false, false)
    layouts[UInt64] = BuiltinLayout("u64", [], false, false, false)
    layouts[Int8] = BuiltinLayout("i8", [], false, false, false)
    layouts[Int16] = BuiltinLayout("i16", [], false, false, false)
    layouts[Int32] = BuiltinLayout("i32", [], false, false, false)
    layouts[Int64] = BuiltinLayout("i64", [], false, false, false)

    if f16
        layouts[Float16] = BuiltinLayout("::half::f16", [], false, false, false)
    else
        layouts[Float16] = UnsupportedLayout("Layouts with Float16 fields can only be generated when f16 is set to true.")
    end

    layouts[Float32] = BuiltinLayout("f32", [], false, false, false)
    layouts[Float64] = BuiltinLayout("f64", [], false, false, false)
    layouts[Bool] = BuiltinLayout("::jlrs::data::layout::bool::Bool", [], false, false, false)
    layouts[Char] = BuiltinLayout("::jlrs::data::layout::char::Char", [], false, false, false)

    if internaltypes
        layouts[Core.SSAValue] = BuiltinLayout("::jlrs::data::layout::ssa_value::SSAValue", [], false, false, false)
    else
        layouts[Core.SSAValue] = UnsupportedLayout("Layouts with Core.SSAValue fields can only be generated when internaltypes is set to true.")
    end

    layouts[Union{}] = BuiltinLayout("::jlrs::data::layout::union::EmptyUnion", [], false, false, false)

    layouts[Any] = BuiltinLayout("::jlrs::data::managed::value::ValueRef", [], true, true, true)
    layouts[basetype(Array)] = BuiltinLayout("::jlrs::data::managed::array::ArrayRef", [StructParameter(:T, true), StructParameter(:N, true)], true, true, true)
    layouts[DataType] = BuiltinLayout("::jlrs::data::managed::datatype::DataTypeRef", [], true, false, true)
    layouts[Module] = BuiltinLayout("::jlrs::data::managed::module::ModuleRef", [], true, false, true)
    layouts[Core.SimpleVector] = BuiltinLayout("::jlrs::data::managed::simple_vector::SimpleVectorRef", [], true, false, true)
    layouts[String] = BuiltinLayout("::jlrs::data::managed::string::StringRef", [], true, false, true)
    layouts[Symbol] = BuiltinLayout("::jlrs::data::managed::symbol::SymbolRef", [], true, false, true)
    layouts[Task] = BuiltinLayout("::jlrs::data::managed::task::TaskRef", [], true, false, true)
    layouts[Core.TypeName] = BuiltinLayout("::jlrs::data::managed::type_name::TypeNameRef", [], true, false, true)
    layouts[TypeVar] = BuiltinLayout("::jlrs::data::managed::type_var::TypeVarRef", [], true, false, true)
    layouts[Union] = BuiltinLayout("::jlrs::data::managed::union::UnionRef", [], true, false, true)
    layouts[UnionAll] = BuiltinLayout("::jlrs::data::managed::union_all::UnionAllRef", [], true, false, true)

    if internaltypes
        layouts[Core.CodeInstance] = BuiltinLayout("::jlrs::data::managed::internal::code_instance::CodeInstanceRef", [], true, false, true)
        layouts[Expr] = BuiltinLayout("::jlrs::data::managed::internal::expr::ExprRef", [], true, false, true)
        layouts[Method] = BuiltinLayout("::jlrs::data::managed::internal::method::MethodRef", [], true, false, true)
        layouts[Core.MethodInstance] = BuiltinLayout("::jlrs::data::managed::internal::method_instance::MethodInstanceRef", [], true, false, true)
        layouts[Core.MethodMatch] = BuiltinLayout("::jlrs::data::managed::internal::method_match::MethodMatchRef", [], true, false, true)
        layouts[Core.MethodTable] = BuiltinLayout("::jlrs::data::managed::internal::method_table::MethodTableRef", [], true, false, true)
        if isdefined(Core, :OpaqueClosure)
            layouts[basetype(Core.OpaqueClosure)] = BuiltinLayout("::jlrs::data::managed::internal::opaque_closure::OpaqueClosureRef", [], true, false, true)
        end
        layouts[Core.TypeMapEntry] = BuiltinLayout("::jlrs::data::managed::internal::typemap_entry::TypeMapEntryRef", [], true, false, true)
        layouts[Core.TypeMapLevel] = BuiltinLayout("::jlrs::data::managed::internal::typemap_level::TypeMapLevelRef", [], true, false, true)
        layouts[WeakRef] = BuiltinLayout("::jlrs::data::managed::weak_ref::WeakRefRef", [], true, false, true)
    else
        layouts[Core.CodeInstance] = BuiltinLayout("::jlrs::data::managed::value::ValueRef", [], true, true, true)
        layouts[Expr] = BuiltinLayout("::jlrs::data::managed::value::ValueRef", [], true, true, true)
        layouts[Method] = BuiltinLayout("::jlrs::data::managed::value::ValueRef", [], true, true, true)
        layouts[Core.MethodInstance] = BuiltinLayout("::jlrs::data::managed::value::ValueRef", [], true, true, true)
        layouts[Core.MethodMatch] = BuiltinLayout("::jlrs::data::managed::value::ValueRef", [], true, true, true)
        layouts[Core.MethodTable] = BuiltinLayout("::jlrs::data::managed::value::ValueRef", [], true, true, true)
        if isdefined(Core, :OpaqueClosure)
            layouts[basetype(Core.OpaqueClosure)] = BuiltinLayout("::jlrs::data::managed::value::ValueRef", [], true, true, true)
        end
        layouts[Core.Method] = BuiltinLayout("::jlrs::data::managed::value::ValueRef", [], true, true, true)
        layouts[Core.TypeMapEntry] = BuiltinLayout("::jlrs::data::managed::value::ValueRef", [], true, true, true)
        layouts[Core.TypeMapLevel] = BuiltinLayout("::jlrs::data::managed::value::ValueRef", [], true, true, true)
        layouts[WeakRef] = BuiltinLayout("::jlrs::data::managed::value::ValueRef", [], true, true, true)
    end

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

# Layouts provided by jlrs
const BUILTINS = begin
    d = Dict{Type,Layout}()
    insertbuiltins!(d)
    d
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

function extracttupledeps_notconcrete!(acc::Dict{DataType,Set{DataType}}, type::DataType, layouts::Dict{Type,Layout})::Nothing
    for ttype in type.types
        extractdeps!(acc, ttype, layouts)
    end

    nothing
end

function extracttupledeps!(acc::Dict{DataType,Set{DataType}}, key::DataType, type::DataType, layouts::Dict{Type,Layout})::Nothing
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

function extractdeps!(acc::Dict{DataType,Set{DataType}}, @nospecialize(type::Type), layouts::Dict{Type,Layout})::Nothing
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
            acc[base] = Set()

            for btype in base.types
                if btype isa DataType
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
                    extractdeps!(acc, btype, layouts)
                elseif btype isa Union
                    if !isnonparametric(btype)
                        error("Unions with type parameters are not supported")
                    end
                    extractdeps!(acc, btype, layouts)
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

function extractparams(@nospecialize(ty::Type), layouts::Dict{Type,Layout})::Set{TypeVar}
    out = Set()
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

function concretetuplefield(@nospecialize(tuple::Type), layouts::Dict{Type,Layout})::TupleLayout
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


function structfield(fieldname::Symbol, @nospecialize(fieldtype::Union{Type,TypeVar}), layouts::Dict{Type,Layout})::StructField
    if fieldtype isa TypeVar
        StructField(fieldname, string(fieldname), GenericLayout(fieldtype.name), [TypeParameter(fieldtype.name, fieldtype)], Set([fieldtype]), false, false, false)
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
            StructField(fieldname, string(fieldname), layouts[Any], [], Set(), true, true, false)
        end
    elseif fieldtype isa Union
        if Base.isbitsunion(fieldtype)
            StructField(fieldname, string(fieldname), BitsUnionLayout(fieldtype), [], Set(), false, false, false)
        else
            StructField(fieldname, string(fieldname), layouts[Any], [], Set(), true, true, false)
        end
    elseif fieldtype == Union{}
        StructField(fieldname, string(fieldname), layouts[Union{}], [], Set(), false, false, false)
    elseif fieldtype <: Tuple
        params = extractparams(fieldtype, layouts)
        if length(params) > 0
            error("Tuples with type parameters are not supported")
        elseif isconcretetype(fieldtype)
            layout = concretetuplefield(fieldtype, layouts)
            StructField(fieldname, string(fieldname), layout, [], Set(), layout.scopelifetime, layout.datalifetime, false)
        else
            StructField(fieldname, string(fieldname), layouts[Any], [], Set(), true, true, false)
        end
    elseif fieldtype isa DataType
        bt = basetype(fieldtype)
        if bt in keys(layouts)
            fieldlayout = layouts[bt]
            if fieldlayout isa StructLayout && ismutabletype(fieldtype)
                StructField(fieldname, string(fieldname), layouts[Any], [], Set(), true, true, false)
            elseif fieldlayout isa AbstractTypeLayout || fieldlayout isa BuiltinAbstractLayout
                StructField(fieldname, string(fieldname), layouts[Any], [], Set(), true, true, false)
            else
                tparams = map(a -> TypeParameter(a[1].name, a[2]), zip(bt.parameters, fieldtype.parameters))
                references = extractparams(fieldtype, layouts)
                StructField(fieldname, string(fieldname), fieldlayout, tparams, references, fieldlayout.scopelifetime, fieldlayout.datalifetime, false)
            end
        elseif Base.uniontype_layout(fieldtype)[1]
            StructField(fieldname, string(fieldname), layouts[Any], [], Set(), true, true, false)
        else
            error("Cannot create field layout")
        end
    else
        error("Unknown field type")
    end
end

function createlayout!(layouts::Dict{Type,Layout}, @nospecialize(type::Type))::Nothing
    bt = basetype(type)

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

    fields = []
    typevars = Set()
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

function haslifetimes(@nospecialize(ty::Type), layouts::Dict{Type,Layout})::Tuple{Bool,Bool}
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

function propagate_internal_param_lifetimes!(layouts::Dict{Type,Layout})::Nothing
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
        string("<", join(generics, ", "), ">")
    end
end

function strsignature(ty::DataType, layouts::Dict{Type,Layout})::String
    if ty <: Tuple
        generics = []

        for ty in ty.types
            push!(generics, strsignature(ty, layouts))
        end

        name = string("::jlrs::data::layout::tuple::Tuple", length(generics))

        if length(generics) > 0
            return string(name, "<", join(generics, ", "), ">")
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
        string(name, "<", join(generics, ", "), ">")
    else
        name
    end

    if wrap_opt
        "::std::option::Option<$name>"
    else
        name
    end
end

function strsignature(layout::StructLayout, field::Union{StructField,TupleField}, layouts::Dict{Type,Layout})::String
    wrap_opt = false

    if field isa StructField && field.fieldtype isa StructLayout && ismutabletype(field.fieldtype.type)
        return "::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>"
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
        string(field.fieldtype.rsname, "<", join(generics, ", "), ">")
    else
        field.fieldtype.rsname
    end

    if wrap_opt
        "::std::option::Option<$n>"
    else
        n
    end
end

function strtuplesignature(layout::StructLayout, field::Union{StructField,TupleField}, layouts::Dict{Type,Layout})::String
    generics = []

    for fieldlayout in field.fieldtype.fields
        push!(generics, strsignature(layout, fieldlayout, layouts))
    end

    if length(generics) > 0
        string(field.fieldtype.rsname, "<", join(generics, ", "), ">")
    else
        field.fieldtype.rsname
    end
end

function strstructname(layout::StructLayout)::String
    generics = strgenerics(layout)
    if generics !== nothing
        string(layout.rsname, generics)
    else
        string(layout.rsname)
    end
end

function structfield_parts(layout::StructLayout, field::StructField, layouts::Dict{Type,Layout})::Vector{String}
    parts = Vector{String}()
    if field.fieldtype isa BitsUnionLayout
        align_field_name = string("_", field.rsname, "_align")
        flag_field_name = string(field.rsname, "_flag")

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
        push!(parts, string(align_field_name, ": ", alignment_ty, ","))
        push!(parts, "#[jlrs(bits_union)]")
        push!(parts, string("pub ", field.rsname, ": ::jlrs::data::layout::union::BitsUnion<", string(size), ">,"))
        push!(parts, "#[jlrs(bits_union_flag)]")
        push!(parts, string("pub ", flag_field_name, ": u8,"))
    else
        sig = strsignature(layout, field, layouts)
        push!(parts, string("pub ", field.rsname, ": ", sig, ","))
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

strlayout(::BuiltinLayout, ::Dict{Type,Layout})::Union{Nothing,String} = nothing
strlayout(::UnsupportedLayout, ::Dict{Type,Layout})::Union{Nothing,String} = nothing
strlayout(::BuiltinAbstractLayout, ::Dict{Type,Layout})::Union{Nothing,String} = nothing

function strlayout(layout::AbstractTypeLayout, ::Dict{Type,Layout})::Union{Nothing,String}
    typepath = string(layout.path)
    if length(typepath) == 0
        modulepath = join(filteredname(layout.typename.module), ".")
        typepath = string(modulepath, ".", layout.typename.name)
    end

    parts = []

    # A separate type constructor is needed due to the presence of elided parameters.
    param_names = map(param -> string(param.name), layout.typeparams)

    push!(parts, "#[derive(ConstructType)]")
    push!(parts, string("#[jlrs(julia_type = \"", typepath, "\")]"))
    if length(param_names) == 0
        push!(parts, string("pub struct ", layout.rsname, " {"))
    else
        push!(parts, string("pub struct ", layout.rsname, "<", join(param_names, ", "), "> {"))
        for param in param_names
            push!(parts, string("    _", lowercase(param), ": ::std::marker::PhantomData<", param, ">,"))
        end
    end
    push!(parts, "}")

    join(parts, "\n")
end

function strlayout(layout::ContainsAtomicFieldsLayout, ::Dict{Type,Layout})::Union{Nothing,String}
    typepath = string(layout.path)
    if length(typepath) == 0
        modulepath = join(filteredname(layout.typename.module), ".")
        typepath = string(modulepath, ".", layout.typename.name)
    end

    parts = []

    # A separate type constructor is needed due to the presence of elided parameters.
    param_names = map(param -> string(param.name), layout.typeparams)

    push!(parts, "#[derive(ConstructType)]")
    push!(parts, string("#[jlrs(julia_type = \"", typepath, "\")]"))
    if length(param_names) == 0
        push!(parts, string("pub struct ", layout.rsname, "TypeConstructor {"))
    else
        push!(parts, string("pub struct ", layout.rsname, "TypeConstructor<", join(param_names, ", "), "> {"))
        for param in param_names
            push!(parts, string("    _", lowercase(param), ": ::std::marker::PhantomData<", param, ">,"))
        end
    end
    push!(parts, "}")

    join(parts, "\n")
end

function strlayout(layout::StructLayout, layouts::Dict{Type,Layout})::Union{Nothing,String}
    ty = getproperty(layout.typename.module, layout.typename.name)

    is_parameter_free = ty isa DataType && isnothing(findfirst(p -> p isa TypeVar, ty.parameters))
    is_bits = is_parameter_free && isbitstype(ty)
    is_zst = is_bits && sizeof(ty) == 0
    is_mut = ismutabletype(basetype(ty))
    is_constructible = isnothing(findfirst(x -> x.elide == true, layout.typeparams))

    traits = ["Clone", "Debug", "Unbox", "ValidLayout", "Typecheck"]
    is_bits && push!(traits, "IntoJulia")
    is_mut || push!(traits, "ValidField")
    is_constructible && push!(traits, "ConstructType")
    is_constructible && !is_zst && !is_mut && push!(traits, "CCallArg", "CCallReturn")

    typepath = string(layout.path)
    if length(typepath) == 0
        modulepath = join(filteredname(layout.typename.module), ".")
        typepath = string(modulepath, ".", layout.typename.name)
    end

    typepath_annotation = string("julia_type = \"", typepath, "\"")

    annotations = Vector{String}()
    push!(annotations, typepath_annotation)
    is_zst && push!(annotations, "zero_sized_type")

    parts = [
        "#[repr(C)]",
        string("#[derive(", join(traits, ", "), ")]"),
        string("#[jlrs(", join(annotations, ", "), ")]"),
        string("pub struct ", strstructname(layout), " {")
    ]
    for field in layout.fields
        for part in structfield_parts(layout, field, layouts)
            push!(parts, string("    ", part))
        end
    end
    push!(parts, "}")

    if !is_constructible
        # A separate type constructor is needed due to the presence of elided parameters.
        param_names = map(param -> string(param.name), layout.typeparams)

        push!(parts, "")
        push!(parts, "#[derive(ConstructType)]")
        push!(parts, string("#[jlrs(", typepath_annotation, ")]"))
        push!(parts, string("pub struct ", layout.rsname, "TypeConstructor<", join(param_names, ", "), "> {"))
        for param in param_names
            push!(parts, string("    _", lowercase(param), ": ::std::marker::PhantomData<", param, ">,"))
        end
        push!(parts, "}")
    end

    join(parts, "\n")
end
end