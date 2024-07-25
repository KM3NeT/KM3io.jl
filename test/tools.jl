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
    @test ismissing(bestjppshower(e))
    @test ismissing(bestaashower(e))
    @test 294.6407542676734 ≈ bestjppmuon(e.trks).lik
    @test ismissing(bestjppshower(e.trks))
    @test ismissing(bestaashower(e.trks))
    close(f)
end

@testset "besttrack()" begin
    f = ROOTFile(datapath("offline", "km3net_offline.root"))
    bt = besttrack(f.offline[1], KM3io.RECONSTRUCTION.JPP_RECONSTRUCTION_TYPE, RecStageRange(KM3io.RECONSTRUCTION.JMUONBEGIN, KM3io.RECONSTRUCTION.JMUONEND))
    @test 294.6407542676734 ≈ bt.lik
    close(f)
end

const ONLINEFILE = datapath("online", "km3net_online.root")


@testset "Offline files" begin
    f = ROOTFile(OFFLINEFILE)
    t = f.offline
    @test 10 == length(t)
    @test 56 == length(t[1].trks)
    @test 0 == length(t[1].w)
    @test 17 == length(t[1].trks[1].fitinf)
    @test 63.92088448672399 == sum(t[end].trks[2].fitinf)
    @test 101.0 == t[1].trks[1].fitinf[end]
    close(f)

    f = ROOTFile(datapath("offline", "numucc.root"))
    h = f.offline.header
    @test 34 == length(propertynames(h))
    @test "NOT" == h.detector
    @test (x = 0, y = 0, z = 0) == h.coord_origin
    @test (program="GENHEN", version="7.2-220514", date=181116, time=1138) == h.physics
    @test (Emin=100, Emax=100000000.0, cosTmin=-1, cosTmax=1) == h.cut_nu
    @test (interaction=1, muon=2, scattering=0, numberOfEnergyBins=1, field_4=12) == h.model

    @test 3.77960885798e11 ≈ sum([h.t for h ∈ f.offline[1].hits])
    @test 65325 ≈ sum([h.channel_id for h ∈ f.offline[1].hits])
    @test 24720688 ≈ sum([h.dom_id for h ∈ f.offline[1].hits])

    @test 65276.89564606823 ≈ sum([h.t for h ∈ f.offline[1].mc_hits])
    @test 3371990 ≈ sum([h.pmt_id for h ∈ f.offline[1].mc_hits])
    @test 94 ≈ sum([h.origin for h ∈ f.offline[1].mc_hits])
    @test -164 ≈ sum([h.type for h ∈ f.offline[1].mc_hits])



    close(f)
end

@testset "Usr fields" begin
    f = ROOTFile(USRFILE)
    evt = f.offline[1]
    @test isapprox(evt.usr["ChargeAbove"], 176.0)
    @test isapprox(evt.usr["NTrigLines"], 6.0)
    @test isapprox(evt.usr["ChargeBelow"], 649.0)
    @test isapprox(evt.usr["ClassficationScore"], 0.168634; atol=1e-6)
    @test isapprox(evt.usr["NTrigHits"], 30.0)
    @test isapprox(evt.usr["NGeometryVetoHits"], 0.0)
    @test isapprox(evt.usr["ChargeRatio"], 0.213333; atol=1e-6)
    @test isapprox(evt.usr["ToT"], 825.0)
    @test isapprox(evt.usr["DeltaPosZ"], 37.5197; atol=1e-4)
    @test isapprox(evt.usr["RecoQuality"], 85.4596; atol=1e-4)
    @test isapprox(evt.usr["LastPartPosZ"], 97.7753; atol=1e-4)
    @test isapprox(evt.usr["NSnapHits"], 51.0)
    @test isapprox(evt.usr["NSpeedVetoHits"], 0.0)
    @test isapprox(evt.usr["RecoNDF"], 37.0)
    @test isapprox(evt.usr["NTrigDOMs"], 7.0)
    @test isapprox(evt.usr["FirstPartPosZ"], 135.295; atol=1e-3)
    @test isapprox(evt.usr["CoC"], 118.63; atol=1e-2)

    f = ROOTFile(OFFLINEFILE)
    evt = f.offline[1]
    @test length(evt.usr) == 0

    for fpath in readdir(datapath("offline"); join=true)
        basename(fpath) == "mcv6.gsg_nue-CCHEDIS_1e4-1e6GeV.sirene.jte.jchain.aanet.1.root" && continue
        f = ROOTFile(fpath)
        if length(f.offline) > 0
            evt = first(f.offline)
            @test typeof(evt.usr) == Dict{String, Float64}
        end
    end
end

@testset "DAQ" begin
    f = ROOTFile(ONLINEFILE)

    s = f.online.summaryslices

    @test 314843.3493190365 ≈ sum(pmtrates(s[1].frames[1]))
    @test 319924.10819387453 ≈ sum(pmtrates(s[1].frames[4]))

    r = pmtrates(s[1])
    @test 64 == length(keys(r))
    @test 15253.971718046887 == r[808981510][1]
    @test 15253.971718046887 == r[808981510][1]

    # Test sample via Jpp from the first summary slice (Frame #5) in ONLINEFILE
    # DOM ID: 806487219
    # UDP max sequence number: 34
    # UDP number of recv packets: 35
    # UDP has trailer: 1
    # white rabbit status: 1
    # status: 1
    #   PMT 0: HRV(0) FIFO(0) rate=8.87337    corrected rate=8.87337  weight=4.16007
    #   PMT 1: HRV(0) FIFO(0) rate=8.63623    corrected rate=8.63623  weight=4.27431
    #   PMT 2: HRV(0) FIFO(0) rate=9.62461    corrected rate=9.62461  weight=3.83537
    #   PMT 3: HRV(0) FIFO(0) rate=8.63623    corrected rate=8.63623  weight=4.27431
    #   PMT 4: HRV(0) FIFO(0) rate=8.18078    corrected rate=8.18078  weight=4.51227
    #   PMT 5: HRV(0) FIFO(0) rate=9.62461    corrected rate=9.62461  weight=3.83537
    #   PMT 6: HRV(0) FIFO(0) rate=11.0206    corrected rate=11.0206  weight=3.34953
    #   PMT 7: HRV(0) FIFO(0) rate=9.11703    corrected rate=9.11703  weight=4.04889
    #   PMT 8: HRV(0) FIFO(0) rate=11.9537    corrected rate=11.9537  weight=3.08809
    #   PMT 9: HRV(0) FIFO(0) rate=14.0634    corrected rate=14.0634  weight=2.62483
    #   PMT 10: HRV(1) FIFO(0) rate=62.3947    corrected rate=62.3947  weight=0.591619
    #   PMT 11: HRV(0) FIFO(0) rate=13.3217    corrected rate=13.3217  weight=2.77096
    #   PMT 12: HRV(1) FIFO(0) rate=1195.37    corrected rate=1195.37  weight=0.0308809
    #   PMT 13: HRV(1) FIFO(0) rate=2000    corrected rate=2000  weight=0.0371656
    #   PMT 14: HRV(1) FIFO(0) rate=2000    corrected rate=2000  weight=0.0371656
    #   PMT 15: HRV(1) FIFO(0) rate=1072.61    corrected rate=1072.61  weight=0.034415
    #   PMT 16: HRV(1) FIFO(0) rate=42.7014    corrected rate=42.7014  weight=0.864467
    #   PMT 17: HRV(1) FIFO(0) rate=840.542    corrected rate=840.542  weight=0.0439168
    #   PMT 18: HRV(1) FIFO(0) rate=575.246    corrected rate=575.246  weight=0.0641706
    #   PMT 19: HRV(1) FIFO(0) rate=2000    corrected rate=2000  weight=0.0371656
    #   PMT 20: HRV(0) FIFO(0) rate=18.9453    corrected rate=18.9453  weight=1.94845
    #   PMT 21: HRV(1) FIFO(0) rate=695.355    corrected rate=695.355  weight=0.0530864
    #   PMT 22: HRV(1) FIFO(0) rate=887.337    corrected rate=887.337  weight=0.0416007
    #   PMT 23: HRV(1) FIFO(0) rate=22.2889    corrected rate=22.2889  weight=1.65616
    #   PMT 24: HRV(1) FIFO(0) rate=71.4449    corrected rate=71.4449  weight=0.516677
    #   PMT 25: HRV(1) FIFO(0) rate=559.872    corrected rate=559.872  weight=0.0659327
    #   PMT 26: HRV(1) FIFO(0) rate=71.4449    corrected rate=71.4449  weight=0.516677
    #   PMT 27: HRV(0) FIFO(0) rate=11.6342    corrected rate=11.6342  weight=3.17288
    #   PMT 28: HRV(0) FIFO(0) rate=16.1032    corrected rate=16.1032  weight=2.29233
    #   PMT 29: HRV(1) FIFO(0) rate=22.2889    corrected rate=22.2889  weight=1.65616
    #   PMT 30: HRV(0) FIFO(0) rate=12.6191    corrected rate=12.6191  weight=2.92523
    frame = s[1].frames[5]

    @test 8873.37466195722 ≈ pmtrate(frame, 0)
    @test 9624.605487994835 ≈ pmtrate(frame, 2)
    @test 12619.146889603864 ≈ pmtrate(frame, 30)
    r = pmtrates(frame)
    @test 31 == length(r)
    @test 8873.37466195722 ≈ r[1]
    @test 9624.605487994835 ≈ r[3]
    @test 12619.146889603864 ≈ r[31]
    for pmt ∈ vcat(0:9, 11, 20, 27:28, 30)
        @test !hrvstatus(frame, pmt)
    end
    for pmt ∈ vcat(10, 12:19, 21:26, 29)
        @test hrvstatus(frame, pmt)
    end

    @test !hrvstatus(s[1].frames[1])
    @test hrvstatus(s[1].frames[2])
    @test hrvstatus(s[1].frames[3])
    @test !hrvstatus(s[1].frames[4])
    @test hrvstatus(s[1].frames[5])

    @test tdcstatus(s[1].frames[1])
    @test !tdcstatus(s[1].frames[2])
    @test !tdcstatus(s[1].frames[3])
    @test tdcstatus(s[1].frames[4])
    @test !tdcstatus(s[1].frames[5])

    @test status(s[1].frames[1])
    @test !status(s[1].frames[5])

    @test 15 == count_active_channels(frame)
    @test 0 == count_fifostatus(frame)
    @test 16 == count_hrvstatus(frame)

    @test 34 == maximal_udp_sequence_number(frame)
    @test 35 == number_of_udp_packets_received(frame)

    # Test sample via Jpp from the first summary slice (Frame #23) in ONLINEFILE
    # DOM ID: 808951460
    # UDP max sequence number: 36
    # UDP number of recv packets: 37
    # UDP has trailer: 1
    # white rabbit status: 1
    # status: 1
    #   PMT 0: HRV(0) FIFO(0) rate=14.0634    corrected rate=14.0634  weight=2.62483
    #   PMT 1: HRV(0) FIFO(0) rate=16.1032    corrected rate=16.1032  weight=2.29233
    #   PMT 2: HRV(0) FIFO(0) rate=18.4389    corrected rate=18.4389  weight=2.00195
    #   PMT 3: HRV(1) FIFO(0) rate=21.1135    corrected rate=21.1135  weight=1.74836
    #   PMT 4: HRV(0) FIFO(0) rate=14.8463    corrected rate=14.8463  weight=2.4864
    #   PMT 5: HRV(0) FIFO(0) rate=11.6342    corrected rate=11.6342  weight=3.17288
    #   PMT 6: HRV(0) FIFO(0) rate=16.5454    corrected rate=16.5454  weight=2.23107
    #   PMT 7: HRV(0) FIFO(0) rate=14.4495    corrected rate=14.4495  weight=2.55468
    #   PMT 8: HRV(0) FIFO(0) rate=17.9461    corrected rate=17.9461  weight=2.05693
    #   PMT 9: HRV(0) FIFO(0) rate=17.9461    corrected rate=17.9461  weight=2.05693
    #   PMT 10: HRV(1) FIFO(0) rate=29.2237    corrected rate=29.2237  weight=1.26315
    #   PMT 11: HRV(1) FIFO(0) rate=21.1135    corrected rate=21.1135  weight=1.74836
    #   PMT 12: HRV(1) FIFO(0) rate=818.078    corrected rate=818.078  weight=0.0451227
    #   PMT 13: HRV(1) FIFO(0) rate=2000    corrected rate=2000  weight=0.0371656
    #   PMT 14: HRV(1) FIFO(0) rate=2000    corrected rate=2000  weight=0.0371656
    #   PMT 15: HRV(1) FIFO(0) rate=1444.95    corrected rate=1444.95  weight=0.0255468
    #   PMT 16: HRV(1) FIFO(0) rate=194.655    corrected rate=194.655  weight=0.189638
    #   PMT 17: HRV(1) FIFO(0) rate=1332.17    corrected rate=1332.17  weight=0.0277096
    #   PMT 18: HRV(1) FIFO(0) rate=2000    corrected rate=2000  weight=0.0371656
    #   PMT 19: HRV(1) FIFO(0) rate=2000    corrected rate=2000  weight=0.0371656
    #   PMT 20: HRV(1) FIFO(0) rate=1016.04    corrected rate=1016.04  weight=0.036331
    #   PMT 21: HRV(1) FIFO(0) rate=2000    corrected rate=2000  weight=0.0371656
    #   PMT 22: HRV(0) FIFO(1) rate=2000    corrected rate=2000  weight=0.0371656
    #   PMT 23: HRV(1) FIFO(0) rate=1261.91    corrected rate=1261.91  weight=0.0292523
    #   PMT 24: HRV(0) FIFO(1) rate=1894.53    corrected rate=1894.53  weight=0.0194845
    #   PMT 25: HRV(0) FIFO(1) rate=2000    corrected rate=2000  weight=0.0371656
    #   PMT 26: HRV(0) FIFO(1) rate=1699.97    corrected rate=1699.97  weight=0.0217144
    #   PMT 27: HRV(1) FIFO(0) rate=65.8684    corrected rate=65.8684  weight=0.560419
    #   PMT 28: HRV(0) FIFO(1) rate=1043.94    corrected rate=1043.94  weight=0.0353601
    #   PMT 29: HRV(0) FIFO(1) rate=2000    corrected rate=2000  weight=0.0371656
    #   PMT 30: HRV(1) FIFO(0) rate=695.355    corrected rate=695.355  weight=0.0530864
    frame = s[1].frames[23]

    for pmt ∈ vcat(0:21, 23, 27, 30)
        @test !fifostatus(frame, pmt)
    end
    for pmt ∈ vcat(22, 24:26, 28:29)
        @test fifostatus(frame, pmt)
    end
    @test !fifostatus(s[1].frames[1])
    @test !fifostatus(s[1].frames[5])
    @test fifostatus(s[1].frames[23])

    # TODO no test file with missing UDP trailers, we need one
    @test all(hasudptrailer(fr) for fr ∈ s[1].frames)

    # TODO no test file with bad white rabbit status, we need one
    @test all(wrstatus(fr) for fr ∈ s[1].frames)

    @test 9 == count_active_channels(frame)
    @test 6 == count_fifostatus(frame)
    @test 16 == count_hrvstatus(frame)

    @test 36 == maximal_udp_sequence_number(frame)
    @test 37 == number_of_udp_packets_received(frame)

    close(f)
end


@testset "helpers" begin
    f = ROOTFile(datapath("mupage", "mcv8.1.mupage_tuned_100G.sirene.jterbr00013288.10.root"))
    for (event, mc_event) in MCEventMatcher(f)
        continue
    end

    rbr = MCEventMatcher(f)
    event, mc_event = rbr[1]
    @assert 756 == length(event.snapshot_hits)
    @assert 28 == length(event.triggered_hits)
    @assert 94 == length(mc_event.mc_hits)
    @assert 2 == length(mc_event.mc_trks)
    event, mc_event = rbr[end]
    @assert 707 == length(event.snapshot_hits)
    @assert 27== length(event.triggered_hits)
    @assert 111 == length(mc_event.mc_hits)
    @assert 4 == length(mc_event.mc_trks)
end


@testset "math" begin
    @test 0 == angle(Direction(1.,0,0), Direction(1.,0,0))
    @test π/2 ≈ angle(Direction(1.,0,0), Direction(0.,1,0))
    @test π/2 ≈ angle(Direction(1.,0,0), Direction(0.,0,1))
    @test π ≈ angle(Direction(1.,0,0), Direction(-1.,0,0))
end
