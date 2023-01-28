struct NonBitsUnion
    a::Union{String,Real}
end

@testset "Structs with non-bits unions" begin
    @test begin
        b = Reflect.reflect([NonBitsUnion])
        sb = Reflect.StringLayouts(b)

        sb[Reflect.basetype(NonBitsUnion)] === """#[repr(C)]
        #[derive(Clone, Debug, Unbox, ValidLayout, Typecheck, ValidField, ConstructType, CCallArg, CCallReturn)]
        #[jlrs(julia_type = "Main.NonBitsUnion")]
        pub struct NonBitsUnion<'scope, 'data> {
            pub a: ::std::option::Option<::jlrs::data::managed::value::ValueRef<'scope, 'data>>,
        }"""
    end
end
