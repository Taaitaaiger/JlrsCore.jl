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
        sb = Reflect.StringWrappers(b)

        sb[MutF32] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.MutF32")]
        pub struct MutF32 {
            pub a: f32,
        }"""
    end

    @test begin
        b = Reflect.reflect([MutNested])
        sb = Reflect.StringWrappers(b)

        sb[MutNested] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.MutNested")]
        pub struct MutNested<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([Immut])
        sb = Reflect.StringWrappers(b)

        sb[Immut] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.Immut")]
        pub struct Immut<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([HasImmut])
        sb = Reflect.StringWrappers(b)

        sb[HasImmut] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.HasImmut")]
        pub struct HasImmut<'frame, 'data> {
            pub a: Immut<'frame, 'data>,
        }"""
    end

    @test begin
        b = Reflect.reflect([DoubleImmut])
        sb = Reflect.StringWrappers(b)

        sb[DoubleImmut] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.DoubleImmut")]
        pub struct DoubleImmut<'frame, 'data> {
            pub a: Immut<'frame, 'data>,
        }"""
    end

    @test begin
        b = Reflect.reflect([HasGeneric])
        sb = Reflect.StringWrappers(b)

        sb[Reflect.basetype(HasGeneric)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.HasGeneric")]
        pub struct HasGeneric<T>
        where
            T: ::jlrs::data::layout::valid_layout::ValidField + Clone,
        {
            pub a: T,
        }"""
    end

    @test begin
        b = Reflect.reflect([HasGenericImmut])
        sb = Reflect.StringWrappers(b)

        sb[Reflect.basetype(HasGenericImmut)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck)]
        #[jlrs(julia_type = "Main.HasGenericImmut")]
        pub struct HasGenericImmut<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([DoubleHasGeneric])
        sb = Reflect.StringWrappers(b)

        sb[Reflect.basetype(DoubleHasGeneric)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck)]
        #[jlrs(julia_type = "Main.DoubleHasGeneric")]
        pub struct DoubleHasGeneric<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end
end
