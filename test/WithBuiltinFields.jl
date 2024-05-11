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
        sb = Reflect.StringLayouts(b)

        sb[WithArray] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithArray")]
        pub struct WithArray<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::array::ArrayRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithCodeInstance])
        sb = Reflect.StringLayouts(b)

        sb[WithCodeInstance] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithCodeInstance")]
        pub struct WithCodeInstance<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithDataType])
        sb = Reflect.StringLayouts(b)

        sb[WithDataType] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithDataType")]
        pub struct WithDataType<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::datatype::DataTypeRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithExpr])
        sb = Reflect.StringLayouts(b)

        sb[WithExpr] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithExpr")]
        pub struct WithExpr<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::expr::ExprRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithString])
        sb = Reflect.StringLayouts(b)

        sb[WithString] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithString")]
        pub struct WithString<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::string::StringRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithMethod])
        sb = Reflect.StringLayouts(b)

        sb[WithMethod] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithMethod")]
        pub struct WithMethod<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithMethodInstance])
        sb = Reflect.StringLayouts(b)

        sb[WithMethodInstance] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithMethodInstance")]
        pub struct WithMethodInstance<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithMethodTable])
        sb = Reflect.StringLayouts(b)

        sb[WithMethodTable] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithMethodTable")]
        pub struct WithMethodTable<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithModule])
        sb = Reflect.StringLayouts(b)

        sb[WithModule] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithModule")]
        pub struct WithModule<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::module::ModuleRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithSimpleVector])
        sb = Reflect.StringLayouts(b)

        sb[WithSimpleVector] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithSimpleVector")]
        pub struct WithSimpleVector<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::simple_vector::SimpleVectorRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithSymbol])
        sb = Reflect.StringLayouts(b)

        sb[WithSymbol] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithSymbol")]
        pub struct WithSymbol<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::symbol::SymbolRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTask])
        sb = Reflect.StringLayouts(b)

        sb[WithTask] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTask")]
        pub struct WithTask<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::task::TaskRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTypeMapEntry])
        sb = Reflect.StringLayouts(b)

        sb[WithTypeMapEntry] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTypeMapEntry")]
        pub struct WithTypeMapEntry<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTypeMapLevel])
        sb = Reflect.StringLayouts(b)

        sb[WithTypeMapLevel] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTypeMapLevel")]
        pub struct WithTypeMapLevel<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTypeName])
        sb = Reflect.StringLayouts(b)

        sb[WithTypeName] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTypeName")]
        pub struct WithTypeName<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::type_name::TypeNameRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTypeVar])
        sb = Reflect.StringLayouts(b)

        sb[WithTypeVar] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTypeVar")]
        pub struct WithTypeVar<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::type_var::TypeVarRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithUnion])
        sb = Reflect.StringLayouts(b)

        sb[WithUnion] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithUnion")]
        pub struct WithUnion<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::union::UnionRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithUnionAll])
        sb = Reflect.StringLayouts(b)

        sb[WithUnionAll] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithUnionAll")]
        pub struct WithUnionAll<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::union_all::UnionAllRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithCodeInstance])
        sb = Reflect.StringLayouts(b)

        sb[WithCodeInstance] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithCodeInstance")]
        pub struct WithCodeInstance<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithArray])
        sb = Reflect.StringLayouts(b)

        sb[WithArray] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithArray")]
        pub struct WithArray<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::array::ArrayRef<'scope, 'data>>,
        }"""
    end



    @test begin
        b = Reflect.reflect([WithDataType])
        sb = Reflect.StringLayouts(b)

        sb[WithDataType] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithDataType")]
        pub struct WithDataType<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::datatype::DataTypeRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithExpr])
        sb = Reflect.StringLayouts(b)

        sb[WithExpr] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithExpr")]
        pub struct WithExpr<'scope> {
            pub a: ::std::option::Option<::jlrs::data::managed::expr::ExprRef<'scope>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithMethod])
        sb = Reflect.StringLayouts(b)

        sb[WithMethod] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithMethod")]
        pub struct WithMethod<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithMethodInstance])
        sb = Reflect.StringLayouts(b)

        sb[WithMethodInstance] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithMethodInstance")]
        pub struct WithMethodInstance<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithMethodTable])
        sb = Reflect.StringLayouts(b)

        sb[WithMethodTable] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithMethodTable")]
        pub struct WithMethodTable<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTypeMapEntry])
        sb = Reflect.StringLayouts(b)

        sb[WithTypeMapEntry] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTypeMapEntry")]
        pub struct WithTypeMapEntry<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithTypeMapLevel])
        sb = Reflect.StringLayouts(b)

        sb[WithTypeMapLevel] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithTypeMapLevel")]
        pub struct WithTypeMapLevel<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end
end
