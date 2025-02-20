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
    Δt = max_t - min_t
    @test [0.8260205110995139, 0.003912907129683348, -0.004395551387888641, -0.5636093359133512] == o(module_id, min_t)
    @test [0.8289446524907407, 0.004590185819553083, -0.0007479055911552097, -0.5593113032456739] == o(module_id, max_t)
    @test [0.8297266567631056, 0.002991865243189534, -0.004798371006076004, -0.5581412898494195] == o(module_id, min_t + Δt/2)
    @test [0.8305219131347711, 0.003947997911424212, -0.0042572917986734805, -0.5569556899628482] == o(module_id, min_t + Δt/3)

    qdata = o(module_id)
    @test 5 == length(qdata.t)
    @test 5 == length(qdata.q)
    @test 1.693407821152e9 == qdata.t[1]
    @test [0.8260205110995139, 0.003912907129683348, -0.004395551387888641, -0.5636093359133512] == qdata.q[1]
end

@testset "Compass" begin
    q = Quaternion(0.8260205110995139, 0.003912907129683348, -0.004395551387888641, -0.5636093359133512)
    c = Compass(q)
    @test c.yaw == 1.1975374212207646
    @test c.pitch == -0.0028509330922497
    @test c.roll == -0.011419325278029469

end
