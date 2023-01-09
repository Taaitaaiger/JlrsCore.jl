struct BitsIntBool
    a::Int
    b::Bool
end

struct BitsCharFloat32Float64
    a::Char
    b::Float32
    c::Float64
end

@testset "Multi-field bits types" begin
    @test begin
        b = Reflect.reflect([BitsIntBool])
        sb = Reflect.StringWrappers(b)

        sb[BitsIntBool] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, IntoJulia, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.BitsIntBool")]
        pub struct BitsIntBool {
            pub a: i64,
            pub b: ::jlrs::data::layout::bool::Bool,
        }"""
    end

    @test begin
        b = Reflect.reflect([BitsCharFloat32Float64])
        sb = Reflect.StringWrappers(b)

        sb[BitsCharFloat32Float64] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, IntoJulia, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.BitsCharFloat32Float64")]
        pub struct BitsCharFloat32Float64 {
            pub a: ::jlrs::data::layout::char::Char,
            pub b: f32,
            pub c: f64,
        }"""
    end
end
