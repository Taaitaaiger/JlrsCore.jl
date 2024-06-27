@enum StandardEnum se_a=1 se_b=2 se_c=3

@enum OtherTypeEnum::Int16 ote_a=1 ote_b=-1 ote_c=0

@testset "Enum types" begin
    @test begin
        b = Reflect.reflect([StandardEnum])
        renamefields!(b, StandardEnum, [:se_a => "SeA", :se_b => "SeB", :se_c => "SeC"])
        sb = Reflect.StringLayouts(b)


        sb[StandardEnum] === """#[repr(i32)]
        #[jlrs(julia_type = "Main.StandardEnum")]
        #[derive(Copy, Clone, Debug, PartialEq, Enum, Unbox, IntoJulia, ConstructType, IsBits, Typecheck, ValidField, ValidLayout, CCallArg, CCallReturn)]
        enum StandardEnum {
            #[allow(non_camel_case_types)]
            #[jlrs(julia_enum_variant = "Main.se_a")]
            SeA = 1,
            #[allow(non_camel_case_types)]
            #[jlrs(julia_enum_variant = "Main.se_b")]
            SeB = 2,
            #[allow(non_camel_case_types)]
            #[jlrs(julia_enum_variant = "Main.se_c")]
            SeC = 3,
        }"""

    end

    @test begin
        b = Reflect.reflect([OtherTypeEnum])
        sb = Reflect.StringLayouts(b)

        sb[OtherTypeEnum] === """#[repr(i16)]
        #[jlrs(julia_type = "Main.OtherTypeEnum")]
        #[derive(Copy, Clone, Debug, PartialEq, Enum, Unbox, IntoJulia, ConstructType, IsBits, Typecheck, ValidField, ValidLayout, CCallArg, CCallReturn)]
        enum OtherTypeEnum {
            #[allow(non_camel_case_types)]
            #[jlrs(julia_enum_variant = "Main.ote_a")]
            ote_a = 1,
            #[allow(non_camel_case_types)]
            #[jlrs(julia_enum_variant = "Main.ote_b")]
            ote_b = -1,
            #[allow(non_camel_case_types)]
            #[jlrs(julia_enum_variant = "Main.ote_c")]
            ote_c = 0,
        }"""
    end
end