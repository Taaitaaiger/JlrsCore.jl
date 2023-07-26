struct BitsIntChar
    a::Int
    b::Char
end

struct BitsCharBitsIntChar
    a::Char
    b::BitsIntChar
end

@testset "Bits types with custom fields" begin
    @test begin
        b = Reflect.reflect([BitsCharBitsIntChar])
        sb = Reflect.StringLayouts(b)

        sb[BitsIntChar] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, IsBits, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.BitsIntChar")]
        pub struct BitsIntChar {
            pub a: i64,
            pub b: ::jlrs::data::layout::char::Char,
        }"""

        sb[BitsCharBitsIntChar] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, IsBits, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.BitsCharBitsIntChar")]
        pub struct BitsCharBitsIntChar {
            pub a: ::jlrs::data::layout::char::Char,
            pub b: BitsIntChar,
        }"""
    end
end
