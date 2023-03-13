@testset "Ledger" begin
    arr = UInt8[]

    @test !Ledger.is_borrowed_shared(arr)
    @test !Ledger.is_borrowed_exclusive(arr)
    @test !Ledger.is_borrowed(arr)

    @test Ledger.try_borrow_shared(arr)
    @test Ledger.is_borrowed_shared(arr)
    @test !Ledger.is_borrowed_exclusive(arr)
    @test Ledger.is_borrowed(arr)
    @test Ledger.unborrow_shared(arr)

    @test !Ledger.is_borrowed_shared(arr)
    @test !Ledger.is_borrowed_exclusive(arr)
    @test !Ledger.is_borrowed(arr)
    @test_throws LedgerError Ledger.unborrow_shared(arr)
    
    @test Ledger.try_borrow_shared(arr)
    @test_throws LedgerError Ledger.try_borrow_exclusive(arr)
    @test Ledger.try_borrow_shared(arr)
    @test Ledger.unborrow_shared(arr)
    @test Ledger.unborrow_shared(arr)


    @test Ledger.try_borrow_exclusive(arr)
    @test !Ledger.is_borrowed_shared(arr)
    @test Ledger.is_borrowed_exclusive(arr)
    @test Ledger.is_borrowed(arr)
    @test_throws LedgerError Ledger.try_borrow_exclusive(arr)
    @test_throws LedgerError Ledger.try_borrow_shared(arr)
    @test Ledger.unborrow_exclusive(arr)
    @test !Ledger.is_borrowed_shared(arr)
    @test !Ledger.is_borrowed_exclusive(arr)
    @test !Ledger.is_borrowed(arr)
end
