@testset "Valid RustResult" begin
    rr = RustResult{UInt}(UInt(1), false)
    @test !rr.is_exc
    @test rr() === UInt(1)
end

@testset "Exceptional RustResult" begin
    rr = RustResult{UInt}(ErrorException("Err"), true)
    @test rr.is_exc
    @test_throws ErrorException rr()
end
