struct Empty end

struct TypedEmpty{T} end

@testset "Struct with no fields" begin
    @test begin
        b = Reflect.reflect([Empty])
        sb = Reflect.StringLayouts(b)

        sb[Empty] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, ConstructType)]
        #[jlrs(julia_type = "Main.Empty", zero_sized_type)]
        pub struct Empty {
        }"""
    end
end

@testset "Struct with type parameter but no fields" begin
    @test begin
        b = Reflect.reflect([TypedEmpty])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(TypedEmpty)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField)]
        #[jlrs(julia_type = "Main.TypedEmpty")]
        pub struct TypedEmpty {
        }

        #[derive(ConstructType)]
        #[jlrs(julia_type = "Main.TypedEmpty")]
        pub struct TypedEmptyTypeConstructor<T> {
            _t: ::std::marker::PhantomData<T>,
        }"""
    end
end
