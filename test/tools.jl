import KM3io: nthbitset, SnapshotHit, tonumifpossible
using Test

@testset "tools" begin
    @testset "nthbitset()" begin
        @test nthbitset(2, 12)
        for n ∈ [1, 3, 5]
            @test nthbitset(n, 42)
        end
        for n ∈ [1, 5, 7, 10, 14, 17, 18, 19, 20, 25, 26, 29, 31, 32, 33, 35, 38, 40, 41, 43, 44, 47, 49, 50, 52, 53, 55, 56]
            @test nthbitset(n, 123456789011121314)
        end
    end
end

@testset "most_frequent()" begin
    a = [1, 1, 2, 3, 1, 5]
    @test 1 == most_frequent(a)

    a = [[1, 2], [1, 2, 3], [1, 2], [1, 2], [1], [1]]
    @test 3 == most_frequent(sum, a)

    a = ['a', 'b', 'c', 'b', 'b', 'd']
    @test 'b' == most_frequent(a)
    @test 'B' == most_frequent(c -> uppercase(c), a; rettype=Char)
end

@testset "categorize()" begin
    hits = [
        SnapshotHit(1, 0, 123, 22),
        SnapshotHit(2, 2, 124, 25),
        SnapshotHit(1, 1, 125, 24),
        SnapshotHit(1, 0, 126, 28),
        SnapshotHit(4, 0, 126, 34),
    ]
    c = categorize(:dom_id, hits)
    @test 3 == length(c[1])
    @test 1 == length(c[2])
    @test 1 == length(c[4])
end

@testset "tonumifpossible()" begin
    @test 1 == tonumifpossible("1")
    @test 1.1 == tonumifpossible("1.1")
    @test "1.1.1" == tonumifpossible("1.1.1")
end
