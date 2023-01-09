struct NonBitsUnion
    a::Union{String,Real}
end

@testset "Structs with non-bits unions" begin
    @test begin
        b = Reflect.reflect([NonBitsUnion])
        sb = Reflect.StringWrappers(b)

        sb[Reflect.basetype(NonBitsUnion)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, ValidField, Typecheck, ConstructType, CCallArg)]
        #[jlrs(julia_type = "Main.NonBitsUnion")]
        pub struct NonBitsUnion<'frame, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'frame, 'data>>,
        }"""
    end
end
