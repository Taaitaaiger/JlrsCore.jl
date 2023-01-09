struct WithArray
    a::Array{Float32,2}
end

struct WithCodeInstance
    a::Core.CodeInstance
end

struct WithDataType
    a::DataType
end

struct WithExpr
    a::Expr
end

struct WithString
    a::String
end

struct WithMethod
    a::Method
end

struct WithMethodInstance
    a::Core.MethodInstance
end

struct WithMethodTable
    a::Core.MethodTable
end

struct WithModule
    a::Module
end

struct WithSimpleVector
    a::Core.SimpleVector
end

struct WithSymbol
    a::Symbol
end

struct WithTask
    a::Task
end

struct WithTypeName
    a::Core.TypeName
end

struct WithTypeVar
    a::TypeVar
end

struct WithTypeMapEntry
    a::Core.TypeMapEntry
end

struct WithTypeMapLevel
    a::Core.TypeMapLevel
end

struct WithUnion
    a::Union
end

struct WithUnionAll
    a::UnionAll
end

@testset "Structs with builtin fields" begin
    @test begin
        b = Reflect.reflect([WithArray])
        sb = Reflect.StringWrappers(b)

        sb[WithArray] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithArray")]
        pub struct WithArray<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::array::ArrayRef<'frame, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithCodeInstance])
        sb = Reflect.StringWrappers(b)

        sb[WithCodeInstance] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithCodeInstance")]
        pub struct WithCodeInstance<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithDataType])
        sb = Reflect.StringWrappers(b)

        sb[WithDataType] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithDataType")]
        pub struct WithDataType<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::datatype::DataTypeRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithExpr])
        sb = Reflect.StringWrappers(b)

        sb[WithExpr] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithExpr")]
        pub struct WithExpr<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithString])
        sb = Reflect.StringWrappers(b)

        sb[WithString] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithString")]
        pub struct WithString<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::string::StringRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithMethod])
        sb = Reflect.StringWrappers(b)

        sb[WithMethod] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithMethod")]
        pub struct WithMethod<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithMethodInstance])
        sb = Reflect.StringWrappers(b)

        sb[WithMethodInstance] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithMethodInstance")]
        pub struct WithMethodInstance<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithMethodTable])
        sb = Reflect.StringWrappers(b)

        sb[WithMethodTable] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithMethodTable")]
        pub struct WithMethodTable<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithModule])
        sb = Reflect.StringWrappers(b)

        sb[WithModule] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithModule")]
        pub struct WithModule<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::module::ModuleRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithSimpleVector])
        sb = Reflect.StringWrappers(b)

        sb[WithSimpleVector] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithSimpleVector")]
        pub struct WithSimpleVector<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::simple_vector::SimpleVectorRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithSymbol])
        sb = Reflect.StringWrappers(b)

        sb[WithSymbol] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithSymbol")]
        pub struct WithSymbol<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::symbol::SymbolRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTask])
        sb = Reflect.StringWrappers(b)

        sb[WithTask] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTask")]
        pub struct WithTask<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::task::TaskRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTypeMapEntry])
        sb = Reflect.StringWrappers(b)

        sb[WithTypeMapEntry] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTypeMapEntry")]
        pub struct WithTypeMapEntry<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTypeMapLevel])
        sb = Reflect.StringWrappers(b)

        sb[WithTypeMapLevel] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTypeMapLevel")]
        pub struct WithTypeMapLevel<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTypeName])
        sb = Reflect.StringWrappers(b)

        sb[WithTypeName] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTypeName")]
        pub struct WithTypeName<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::type_name::TypeNameRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTypeVar])
        sb = Reflect.StringWrappers(b)

        sb[WithTypeVar] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTypeVar")]
        pub struct WithTypeVar<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::type_var::TypeVarRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithUnion])
        sb = Reflect.StringWrappers(b)

        sb[WithUnion] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithUnion")]
        pub struct WithUnion<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::union::UnionRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithUnionAll])
        sb = Reflect.StringWrappers(b)

        sb[WithUnionAll] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithUnionAll")]
        pub struct WithUnionAll<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::union_all::UnionAllRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithCodeInstance]; internaltypes=true)
        sb = Reflect.StringWrappers(b)

        sb[WithCodeInstance] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithCodeInstance")]
        pub struct WithCodeInstance<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::internal::code_instance::CodeInstanceRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithArray])
        sb = Reflect.StringWrappers(b)

        sb[WithArray] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithArray")]
        pub struct WithArray<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::array::ArrayRef<'frame, 'data>>,
        }"""
    end



    @test begin
        b = Reflect.reflect([WithDataType])
        sb = Reflect.StringWrappers(b)

        sb[WithDataType] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithDataType")]
        pub struct WithDataType<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::datatype::DataTypeRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithExpr]; internaltypes=true)
        sb = Reflect.StringWrappers(b)

        sb[WithExpr] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithExpr")]
        pub struct WithExpr<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::internal::expr::ExprRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithMethod]; internaltypes=true)
        sb = Reflect.StringWrappers(b)

        sb[WithMethod] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithMethod")]
        pub struct WithMethod<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::internal::method::MethodRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithMethodInstance]; internaltypes=true)
        sb = Reflect.StringWrappers(b)

        sb[WithMethodInstance] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithMethodInstance")]
        pub struct WithMethodInstance<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::internal::method_instance::MethodInstanceRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithMethodTable]; internaltypes=true)
        sb = Reflect.StringWrappers(b)

        sb[WithMethodTable] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithMethodTable")]
        pub struct WithMethodTable<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::internal::method_table::MethodTableRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTypeMapEntry]; internaltypes=true)
        sb = Reflect.StringWrappers(b)

        sb[WithTypeMapEntry] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTypeMapEntry")]
        pub struct WithTypeMapEntry<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::internal::typemap_entry::TypeMapEntryRef<'frame>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTypeMapLevel]; internaltypes=true)
        sb = Reflect.StringWrappers(b)

        sb[WithTypeMapLevel] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTypeMapLevel")]
        pub struct WithTypeMapLevel<'frame> {
            pub a: ::std::option::Option<::jlrs::data::managed::internal::typemap_level::TypeMapLevelRef<'frame>>,
        }"""
    end
end
