import KM3io: nthbitset
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
