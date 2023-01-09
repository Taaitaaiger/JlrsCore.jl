mutable struct HasAtomicField
    @atomic a::Int32
end

struct WithInt32
    int32::Int32
end

mutable struct HasCustomAtomicField
    @atomic a::WithInt32
end

@testset "Structs with atomic fields are skipped" begin
    @test begin
        b = Reflect.reflect([HasAtomicField])
        sb = Reflect.StringWrappers(b)

        haskey(sb.dict, Reflect.basetype(HasAtomicField)) == false
    end
end

@testset "Fields of structs with atomic fields are included" begin
    @test begin
        b = Reflect.reflect([HasCustomAtomicField])
        sb = Reflect.StringWrappers(b)

        sb[WithInt32] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, IntoJulia, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithInt32")]
        pub struct WithInt32 {
            pub int32: i32,
        }"""

    end
end
