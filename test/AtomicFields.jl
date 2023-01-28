mutable struct HasAtomicField
    @atomic a::Int32
end

struct WithInt32
    int32::Int32
end

mutable struct HasCustomAtomicField
    @atomic a::WithInt32
end

@testset "Only a type constructor is generated for structs with atomic fields" begin
    @test begin
        b = Reflect.reflect([HasAtomicField])
        sb = Reflect.StringLayouts(b)

        sb.dict[Reflect.basetype(HasAtomicField)] === """#[derive(ConstructType)]
        #[jlrs(julia_type = "Main.HasAtomicField")]
        pub struct HasAtomicFieldTypeConstructor {
        }"""
    end
end

@testset "Fields of structs with atomic fields are included" begin
    @test begin
        b = Reflect.reflect([HasCustomAtomicField])
        sb = Reflect.StringLayouts(b)

        sb[WithInt32] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.WithInt32")]
        pub struct WithInt32 {
            pub int32: i32,
        }"""

    end
end
