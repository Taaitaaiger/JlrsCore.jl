struct WithGenericT{T}
    a::T
end

struct WithNestedGenericT{T}
    a::WithGenericT{T}
end

struct WithSetGeneric
    a::WithGenericT{Int64}
end

struct WithValueType{N}
    a::Int64
end

struct WithGenericUnionAll
    a::WithGenericT
end

struct WithGenericTuple{T}
    a::Tuple{T}
end

struct WithSetGenericTuple
    a::Tuple{WithGenericT{Int64}}
end

struct WithPropagatedLifetime
    a::WithGenericT{Module}
end

struct WithPropagatedLifetimes
    a::WithGenericT{Tuple{Int32, WithGenericT{Array{Int32, 2}}}}
end

@testset "Structs with generic fields" begin
    @test begin
        b = Reflect.reflect([WithGenericT])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(WithGenericT)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.WithGenericT")]
        pub struct WithGenericT<T> {
            pub a: T,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithNestedGenericT])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(WithNestedGenericT)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.WithNestedGenericT")]
        pub struct WithNestedGenericT<T> {
            pub a: WithGenericT<T>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithSetGeneric])
        sb = Reflect.StringLayouts(b)

        sb[WithSetGeneric] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.WithSetGeneric")]
        pub struct WithSetGeneric {
            pub a: WithGenericT<i64>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithValueType])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(WithValueType)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField)]
        #[jlrs(julia_type = "Main.WithValueType")]
        pub struct WithValueType {
            pub a: i64,
        }

        #[derive(ConstructType)]
        #[jlrs(julia_type = "Main.WithValueType")]
        pub struct WithValueTypeTypeConstructor<N> {
            _n: ::std::marker::PhantomData<N>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithGenericUnionAll])
        sb = Reflect.StringLayouts(b)

        sb[WithGenericUnionAll] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.WithGenericUnionAll")]
        pub struct WithGenericUnionAll<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test_throws ErrorException begin
        Reflect.reflect([WithGenericTuple])
    end

    @test begin
        b = Reflect.reflect([WithSetGenericTuple])
        sb = Reflect.StringLayouts(b)

        sb[WithSetGenericTuple] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.WithSetGenericTuple")]
        pub struct WithSetGenericTuple {
            pub a: ::jlrs::data::layout::tuple::Tuple1<WithGenericT<i64>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithPropagatedLifetime])
        sb = Reflect.StringLayouts(b)

        sb[WithPropagatedLifetime] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.WithPropagatedLifetime")]
        pub struct WithPropagatedLifetime<'scope> {
            pub a: WithGenericT<::std::option::Option<::jlrs::data::managed::module::ModuleRef<'scope>>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithPropagatedLifetimes])
        sb = Reflect.StringLayouts(b)

        sb[WithPropagatedLifetimes] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.WithPropagatedLifetimes")]
        pub struct WithPropagatedLifetimes<'scope, 'data> {
            pub a: WithGenericT<::jlrs::data::layout::tuple::Tuple2<i32, WithGenericT<::std::option::Option<::jlrs::data::managed::array::ArrayRef<'scope, 'data>>>>>,
        }"""
    end
end