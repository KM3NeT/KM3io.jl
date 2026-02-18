using KM3io
using KM3NeTTestData
using Test


@testset "haversine" begin
    arca = Detector(datapath("detx", "KM3NeT_00000133_20221025.detx"))
    orca = Detector(datapath("detx", "D_ORCA006_t.A02181836.p.A02181837.r.A02182001.detx"))
    @test isapprox(1.1175809517026003e6, haversine(arca, orca))
end


@testset "rotations" begin
    arca = Detector(datapath("detx", "KM3NeT_00000133_20221025.detx"))
    orca = Detector(datapath("detx", "D_ORCA006_t.A02181836.p.A02181837.r.A02182001.detx"))
    R = rotmatrix(arca, orca)
    @test [0.13931456136972714, -0.10511045399085633, 0.9846538708867174] == R*Direction(0.0, 0.0, 1.0)
end
