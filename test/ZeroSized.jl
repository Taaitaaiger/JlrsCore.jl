struct Empty end

struct TypedEmpty{T} end

@testset "Struct with no fields" begin
    @test begin
        b = Reflect.reflect([Empty])
        sb = Reflect.StringWrappers(b)

        sb[Empty] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, IntoJulia, ConstructType)]
        #[jlrs(julia_type = "Main.Empty", zero_sized_type)]
        pub struct Empty {
        }"""
    end
end

@testset "Struct with type parameter but no fields" begin
    @test begin
        b = Reflect.reflect([TypedEmpty])
        sb = Reflect.StringWrappers(b)

        sb[Reflect.basetype(TypedEmpty)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck)]
        #[jlrs(julia_type = "Main.TypedEmpty")]
        pub struct TypedEmpty {
        }"""
    end
end
