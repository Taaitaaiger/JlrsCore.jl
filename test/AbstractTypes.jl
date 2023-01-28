abstract type AnAbstractType end
abstract type AnAbstractUnionAll{T<:AnAbstractType} end

struct HasAbstractField
    a::AnAbstractType
end

struct HasAbstractUnionAllField
    a::AnAbstractUnionAll
end

struct HasGenericAbstractField{T<:AnAbstractType}
    a::T
end

struct HasGenericAbstractUnionAllField{T<:AnAbstractType, U<:AnAbstractUnionAll{T}}
    a::U
end

@testset "Type constructor is generated for abstract type" begin
    @test begin
        b = Reflect.reflect([AnAbstractType])
        sb = Reflect.StringLayouts(b)

        sb[AnAbstractType] === """#[derive(ConstructType)]
        #[jlrs(julia_type = "Main.AnAbstractType")]
        pub struct AnAbstractType {
        }"""
    end

    @test begin
        b = Reflect.reflect([AnAbstractUnionAll])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(AnAbstractUnionAll)] === """#[derive(ConstructType)]
        #[jlrs(julia_type = "Main.AnAbstractUnionAll")]
        pub struct AnAbstractUnionAll<T> {
            _t: ::std::marker::PhantomData<T>,
        }"""
    end
end

@testset "Abstract field becomes ValueRef" begin
    @test begin
        b = Reflect.reflect([HasAbstractField])
        sb = Reflect.StringLayouts(b)

        sb[HasAbstractField] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.HasAbstractField")]
        pub struct HasAbstractField<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([HasAbstractUnionAllField])
        sb = Reflect.StringLayouts(b)

        sb[HasAbstractUnionAllField] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.HasAbstractUnionAllField")]
        pub struct HasAbstractUnionAllField<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end
end

@testset "Generic abstract field remains generic" begin
    @test begin
        b = Reflect.reflect([HasGenericAbstractField])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(HasGenericAbstractField)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.HasGenericAbstractField")]
        pub struct HasGenericAbstractField<T> {
            pub a: T,
        }"""
    end

    @test begin
        b = Reflect.reflect([HasGenericAbstractUnionAllField])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(HasGenericAbstractUnionAllField)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField)]
        #[jlrs(julia_type = "Main.HasGenericAbstractUnionAllField")]
        pub struct HasGenericAbstractUnionAllField<U> {
            pub a: U,
        }

        #[derive(ConstructType)]
        #[jlrs(julia_type = "Main.HasGenericAbstractUnionAllField")]
        pub struct HasGenericAbstractUnionAllFieldTypeConstructor<T, U> {
            _t: ::std::marker::PhantomData<T>,
            _u: ::std::marker::PhantomData<U>,
        }"""
    end
end
