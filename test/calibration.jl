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


@testset "orientations" begin
    o = read(datapath("calib", "KM3NeT_00000133_D_1.0.0_00017397_00017496_1.orientations.root"), Orientations)
    module_id = 817589211
    min_t, max_t = extrema(o.times[module_id])
    @test [0.8260205110995139, 0.003912907129683348, -0.004395551387888641, -0.5636093359133512] == o(module_id, min_t)
    @test [0.8289446524907407, 0.004590185819553083, -0.0007479055911552097, -0.5593113032456739] == o(module_id, max_t)
end
