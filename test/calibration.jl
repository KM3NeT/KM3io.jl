using KM3io
using KM3NeTTestData
using Test

@testset "Hit calibration" begin
    f = ROOTFile(datapath("online", "km3net_online.root"))
    hits = f.online.events[1].snapshot_hits
    det = Detector(datapath("detx", "km3net_offline.detx"))
    chits = calibrate(det, hits)
    @test 96 == length(hits)
    @test 96 == length(chits)

    @test 30733918 == hits[1].t
    @test 3.0941664391e7 ≈ chits[1].t

    chits = calibratetime(det, hits)
    @test 3.0941664391e7 ≈ chits[1].t
end


@testset "floordist()" begin
    det = Detector(datapath("detx", "km3net_offline.detx"))
    @test 9.61317647058823 ≈ floordist(det)
end
