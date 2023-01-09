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
        sb = Reflect.StringWrappers(b)

        sb[Reflect.basetype(WithGenericT)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithGenericT")]
        pub struct WithGenericT<T>
        where
            T: ::jlrs::data::layout::valid_layout::ValidField + Clone,
        {
            pub a: T,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithNestedGenericT])
        sb = Reflect.StringWrappers(b)

        sb[Reflect.basetype(WithNestedGenericT)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithNestedGenericT")]
        pub struct WithNestedGenericT<T>
        where
            T: ::jlrs::data::layout::valid_layout::ValidField + Clone,
        {
            pub a: WithGenericT<T>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithSetGeneric])
        sb = Reflect.StringWrappers(b)

        sb[WithSetGeneric] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, IntoJulia, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithSetGeneric")]
        pub struct WithSetGeneric {
            pub a: WithGenericT<i64>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithValueType])
        sb = Reflect.StringWrappers(b)

        sb[Reflect.basetype(WithValueType)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck)]
        #[jlrs(julia_type = "Main.WithValueType")]
        pub struct WithValueType {
            pub a: i64,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithGenericUnionAll])
        sb = Reflect.StringWrappers(b)

        sb[WithGenericUnionAll] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithGenericUnionAll")]
        pub struct WithGenericUnionAll<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end

    @test_throws ErrorException begin
        Reflect.reflect([WithGenericTuple])
    end

    @test begin
        b = Reflect.reflect([WithSetGenericTuple])
        sb = Reflect.StringWrappers(b)

        sb[WithSetGenericTuple] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, IntoJulia, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithSetGenericTuple")]
        pub struct WithSetGenericTuple {
            pub a: ::jlrs::data::layout::tuple::Tuple1<WithGenericT<i64>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithPropagatedLifetime])
        sb = Reflect.StringWrappers(b)

        sb[WithPropagatedLifetime] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithPropagatedLifetime")]
        pub struct WithPropagatedLifetime<'frame> {
            pub a: WithGenericT<::std::option::Option<::jlrs::data::managed::module::ModuleRef<'frame>>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithPropagatedLifetimes])
        sb = Reflect.StringWrappers(b)

        sb[WithPropagatedLifetimes] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithPropagatedLifetimes")]
        pub struct WithPropagatedLifetimes<'frame, 'data> {
            pub a: WithGenericT<::jlrs::data::layout::tuple::Tuple2<i32, WithGenericT<::std::option::Option<::jlrs::data::managed::array::ArrayRef<'frame, 'data>>>>>,
        }"""
    end
end