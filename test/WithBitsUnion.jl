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

struct Elided{A, B}
    a::B
end

struct WithElidedInUnion
    a::Union{Int16, Elided{1, Int64}, Float64}
end

@testset "Structs with bits unions" begin
    @test begin
        b = Reflect.reflect([SingleVariant], typed_bits_union=true)
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(SingleVariant)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, IntoJulia, ValidField, IsBits, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.SingleVariant")]
        pub struct SingleVariant {
            pub a: i32,
        }"""
    end

    @test begin
        b = Reflect.reflect([DoubleVariant], typed_bits_union=true)
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(DoubleVariant)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.DoubleVariant")]
        pub struct DoubleVariant {
            #[jlrs(bits_union_align)]
            _a_align: ::jlrs::data::layout::union::Align4,
            #[jlrs(bits_union)]
            pub a: ::jlrs::data::layout::union::TypedBitsUnion<::jlrs::UnionOf![i16, i32], 4>,
            #[jlrs(bits_union_flag)]
            pub a_flag: u8,
        }"""
    end

    @test begin
        b = Reflect.reflect([SizeAlignMismatch], typed_bits_union=true)
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(SizeAlignMismatch)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.SizeAlignMismatch")]
        pub struct SizeAlignMismatch {
            #[jlrs(bits_union_align)]
            _a_align: ::jlrs::data::layout::union::Align4,
            #[jlrs(bits_union)]
            pub a: ::jlrs::data::layout::union::TypedBitsUnion<::jlrs::UnionOf![i32, ::jlrs::data::layout::tuple::Tuple3<i16, i16, i16>], 6>,
            #[jlrs(bits_union_flag)]
            pub a_flag: u8,
        }"""
    end

    @test begin
        b = Reflect.reflect([UnionInTuple])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(UnionInTuple)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.UnionInTuple")]
        pub struct UnionInTuple<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::WeakValue<'scope, 'data>>,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithElidedInUnion], typed_bits_union=true)
        sb = Reflect.StringLayouts(b)

        sb[WithElidedInUnion] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithElidedInUnion")]
        pub struct WithElidedInUnion {
            #[jlrs(bits_union_align)]
            _a_align: ::jlrs::data::layout::union::Align8,
            #[jlrs(bits_union)]
            pub a: ::jlrs::data::layout::union::TypedBitsUnion<::jlrs::UnionOf![f64, i16, ElidedTypeConstructor<::jlrs::data::types::construct_type::ConstantI64<1>, i64>], 8>,
            #[jlrs(bits_union_flag)]
            pub a_flag: u8,
        }"""
    end

    @test begin
        b = Reflect.reflect([WithElidedInUnion])
        sb = Reflect.StringLayouts(b)

        sb[WithElidedInUnion] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.WithElidedInUnion")]
        pub struct WithElidedInUnion {
            #[jlrs(bits_union_align)]
            _a_align: ::jlrs::data::layout::union::Align8,
            #[jlrs(bits_union)]
            pub a: ::jlrs::data::layout::union::BitsUnion<8>,
            #[jlrs(bits_union_flag)]
            pub a_flag: u8,
        }"""
    end

    @test_throws ErrorException begin
        b = Reflect.reflect([GenericInUnion])
    end
end
