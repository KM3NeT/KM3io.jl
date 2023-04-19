using KM3io
import KM3io: nthbitset, SnapshotHit, tonumifpossible
using KM3NeTTestData
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

@testset "has...() helpers" begin
    f = ROOTFile(datapath("offline", "km3net_offline.root"))
    e = f.offline[1]
    t = e.trks |> first
    @test hasjppmuonprefit(t)
    @test !hasjppmuonsimplex(t)
    @test hasjppmuongandalf(t)
    @test hasjppmuonenergy(t)
    @test hasjppmuonstart(t)
    @test hasjppmuonfit(t)
    @test !hasshowerprefit(t)
    @test !hasshowerpositionfit(t)
    @test !hasshowercompletefit(t)
    @test !hasshowerfit(t)
    @test !hasaashowerfit(t)
    @test hasreconstructedjppmuon(e)
    @test !hasreconstructedjppshower(e)
    @test !hasreconstructedaashower(e)
    @test 294.6407542676734 ≈ bestjppmuon(e).lik
    @test isnothing(bestjppshower(e))
    @test isnothing(bestaashower(e))
    @test 294.6407542676734 ≈ bestjppmuon(e.trks).lik
    @test isnothing(bestjppshower(e.trks))
    @test isnothing(bestaashower(e.trks))
    close(f)
end

@testset "besttrack()" begin
    f = ROOTFile(datapath("offline", "km3net_offline.root"))
    bt = besttrack(f.offline[1], KM3io.RECONSTRUCTION.JPP_RECONSTRUCTION_TYPE, RecStageRange(KM3io.RECONSTRUCTION.JMUONBEGIN, KM3io.RECONSTRUCTION.JMUONEND))
    @test 294.6407542676734 ≈ bt.lik
    close(f)
end
