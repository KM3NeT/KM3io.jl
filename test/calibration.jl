using KM3io
using KM3NeTTestData
using Test

@testset "Hit calibration" begin
    f = OnlineFile(datapath("online", "km3net_online.root"))
    hits = f.events[1].snapshot_hits
    det = Detector(datapath("detx", "km3net_offline.detx"))
    chits = calibrate(det, hits)
    @test 96 == length(hits)
    @test 96 == length(chits)
end


@testset "floordist()" begin
    det = Detector(datapath("detx", "km3net_offline.detx"))
    @test 9.61317647058823 ≈ floordist(det)
end
