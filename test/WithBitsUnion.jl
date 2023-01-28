struct SingleVariant
    a::Union{Int32}
end

struct DoubleVariant
    a::Union{Int16, Int32}
end

struct SizeAlignMismatch
    a::Union{Tuple{Int16, Int16, Int16}, Int32}
end

struct UnionInTuple
    a::Tuple{Union{Int16, Int32}}
end

struct GenericInUnion{T}
    a::Union{T, Int32}
end

@testset "Structs with bits unions" begin
    @test begin
        b = Reflect.reflect([SingleVariant])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(SingleVariant)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.SingleVariant")]
        pub struct SingleVariant {
            pub a: i32,
        }"""
    end

    @test begin
        b = Reflect.reflect([DoubleVariant])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(DoubleVariant)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.DoubleVariant")]
        pub struct DoubleVariant {
            #[jlrs(bits_union_align)]
            _a_align: ::jlrs::data::layout::union::Align4,
            #[jlrs(bits_union)]
            pub a: ::jlrs::data::layout::union::BitsUnion<4>,
            #[jlrs(bits_union_flag)]
            pub a_flag: u8,
        }"""
    end

    @test begin
        b = Reflect.reflect([SizeAlignMismatch])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(SizeAlignMismatch)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.SizeAlignMismatch")]
        pub struct SizeAlignMismatch {
            #[jlrs(bits_union_align)]
            _a_align: ::jlrs::data::layout::union::Align4,
            #[jlrs(bits_union)]
            pub a: ::jlrs::data::layout::union::BitsUnion<6>,
            #[jlrs(bits_union_flag)]
            pub a_flag: u8,
        }"""
    end

    @test begin
        b = Reflect.reflect([UnionInTuple])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(UnionInTuple)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.UnionInTuple")]
        pub struct UnionInTuple<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end

    @test_throws ErrorException begin
        b = Reflect.reflect([GenericInUnion])
    end
end
