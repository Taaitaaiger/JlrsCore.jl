mutable struct MutF32
    a::Float32
end

mutable struct MutNested
    a::MutF32
end

struct Immut
    a::MutF32
end

mutable struct HasImmut
    a::Immut
end

struct DoubleImmut
    a::Immut
end

mutable struct HasGeneric{T}
    a::T
end

struct HasGenericImmut{T}
    a::HasGeneric{T}
end

mutable struct DoubleHasGeneric{T}
    a::HasGeneric{T}
end

@testset "Mutable structs" begin
    @test begin
        b = Reflect.reflect([MutF32])
        sb = Reflect.StringLayouts(b)

        sb[MutF32] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ConstructType)]
        #[jlrs(julia_type = "Main.MutF32")]
        pub struct MutF32 {
            pub a: f32,
        }"""
    end

    @test begin
        b = Reflect.reflect([MutNested])
        sb = Reflect.StringLayouts(b)

        sb[MutNested] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ConstructType)]
        #[jlrs(julia_type = "Main.MutNested")]
        pub struct MutNested<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([MutNested])
        !(MutF32 in keys(b.dict))
    end

    @test begin
        b = Reflect.reflect([Immut])
        sb = Reflect.StringLayouts(b)

        sb[Immut] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.Immut")]
        pub struct Immut<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([HasImmut])
        sb = Reflect.StringLayouts(b)

        sb[HasImmut] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ConstructType)]
        #[jlrs(julia_type = "Main.HasImmut")]
        pub struct HasImmut<'scope, 'data> {
            pub a: Immut<'scope, 'data>,
        }"""
    end

    @test begin
        b = Reflect.reflect([DoubleImmut])
        sb = Reflect.StringLayouts(b)

        sb[DoubleImmut] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.DoubleImmut")]
        pub struct DoubleImmut<'scope, 'data> {
            pub a: Immut<'scope, 'data>,
        }"""
    end

    @test begin
        b = Reflect.reflect([HasGeneric])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(HasGeneric)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ConstructType)]
        #[jlrs(julia_type = "Main.HasGeneric")]
        pub struct HasGeneric<T> {
            pub a: T,
        }"""
    end

    @test begin
        b = Reflect.reflect([HasGenericImmut])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(HasGenericImmut)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField)]
        #[jlrs(julia_type = "Main.HasGenericImmut")]
        pub struct HasGenericImmut<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }

        #[derive(ConstructType, HasLayout)]
        #[jlrs(julia_type = "Main.HasGenericImmut", constructor_for = "HasGenericImmut", scope_lifetime = true, data_lifetime = true, layout_params = [], elided_params = ["T"], all_params = ["T"])]
        pub struct HasGenericImmutTypeConstructor<T> {
            _t: ::std::marker::PhantomData<T>,
        }"""
    end

    @test begin
        b = Reflect.reflect([DoubleHasGeneric])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(DoubleHasGeneric)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck)]
        #[jlrs(julia_type = "Main.DoubleHasGeneric")]
        pub struct DoubleHasGeneric<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }

        #[derive(ConstructType, HasLayout)]
        #[jlrs(julia_type = "Main.DoubleHasGeneric", constructor_for = "DoubleHasGeneric", scope_lifetime = true, data_lifetime = true, layout_params = [], elided_params = ["T"], all_params = ["T"])]
        pub struct DoubleHasGenericTypeConstructor<T> {
            _t: ::std::marker::PhantomData<T>,
        }"""
    end
end
