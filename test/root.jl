using KM3io
import UnROOT
using KM3NeTTestData
using Test


const DETX = datapath("detx", "detx_v3.detx")
const DETX_44 = datapath("detx", "km3net_offline.detx")
const ONLINEFILE = datapath("online", "km3net_online.root")
const OFFLINEFILE = datapath("offline", "km3net_offline.root")
const USRFILE = datapath("offline", "usr-sample.root")


@testset "Offline files" begin
    f = ROOTFile(OFFLINEFILE)
    t = f.offline
    @test 10 == length(t)
    @test 56 == length(t[1].trks)
    @test 0 == length(t[1].w)
    @test 17 == length(t[1].trks[1].fitinf)
    @test 0.009290906625313346 == t[end].trks[1].fitinf[0]
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

    n_events = length(f.offline)
    n = Threads.Atomic{Int}(0)
    n_total_tracks = Threads.Atomic{Int}(0)
    Threads.@threads for event in f.offline
        Threads.atomic_add!(n, 1)
        n_tracks = 0
        for track in event.trks
            n_tracks += 1
        end
        Threads.atomic_add!(n_total_tracks, n_tracks)
    end
    @test 407 == n_total_tracks[]


    close(f)
end

@testset "OfflineEventTape" begin
    t = KM3io.OfflineEventTape([
        datapath("online", "km3net_online.root")
    ])
    @test length(collect(t)) == 0

    t = KM3io.OfflineEventTape([
        datapath("online", "km3net_online.root"),
        datapath("online", "km3net_online.root"),
        datapath("online", "km3net_online.root")
    ])
    @test length(collect(t)) == 0

    # Testing some edge cases where first/last/middle files have
    # no offline events
    source_configurations = [
        (0, [
            datapath("online", "km3net_online.root"),
            datapath("online", "km3net_online.root"),
            datapath("online", "km3net_online.root")
        ]),
        (30, [
            datapath("offline", "km3net_offline.root"),
            datapath("offline", "km3net_offline.root"),
            datapath("offline", "km3net_offline.root")
        ]),
        (10, [
            datapath("offline", "km3net_offline.root"),
            datapath("online", "km3net_online.root"),
            datapath("online", "km3net_online.root")
        ]),
        (10, [
            datapath("online", "km3net_online.root"),
            datapath("offline", "km3net_offline.root"),
            datapath("online", "km3net_online.root")
        ]),
        (20, [
            datapath("offline", "km3net_offline.root"),
            datapath("online", "km3net_online.root"),
            datapath("offline", "km3net_offline.root")
        ]),
        (20, [
            datapath("online", "km3net_online.root"),
            datapath("offline", "km3net_offline.root"),
            datapath("offline", "km3net_offline.root"),
            datapath("online", "km3net_online.root"),
        ]),
        (10, [
            datapath("online", "km3net_online.root"),
            datapath("online", "km3net_online.root"),
            datapath("offline", "km3net_offline.root")
        ])
    ]
    for (n_expected, sources) in source_configurations
        t = KM3io.OfflineEventTape(sources)
        @test length(collect(t)) == n_expected
        t.show_progress = true
        @test length(collect(t)) == n_expected
    end

    sources = [
        datapath("offline", "km3net_offline.root"),
        datapath("offline", "numucc.root"),
        datapath("online", "km3net_online.root"),
        datapath("offline", "muon_cc_events.root")
    ]
    reference_events = vcat([collect(ROOTFile(source).offline) for source in sources]...)
    tape = OfflineEventTape(sources)
    tape_events = collect(tape)
    for (event_a, event_b) in zip(reference_events, tape_events)
        @test event_a == event_b
    end
    tape_events = collect(tape)  # test twice because of caching
    for (event_a, event_b) in zip(reference_events, tape_events)
        @test event_a == event_b
    end
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

@testset "Online files" begin
    f = ROOTFile(ONLINEFILE)
    hits = f.online.events.snapshot_hits
    @test 3 == length(hits)  # grouped by event
    @test 96 == length(hits[1])
    @test [806451572, 806451572, 806455814] == [h.dom_id for h in hits[1][1:3]]
    @test [809524432, 809524432, 809544061] == [h.dom_id for h in hits[1][end-2:end]]
    @test [30733918, 30733916, 30733256] == [h.t for h in hits[1][1:3]]
    @test [30733864, 30734686, 30735112] == [h.t for h in hits[1][end-2:end]]
    @test [10, 13, 0, 3, 1] == [h.channel_id for h in hits[1][1:5]]
    @test [10, 10, 22, 24, 17] == [h.channel_id for h in hits[1][end-4:end]]
    @test [26, 19, 25, 22, 28] == [h.tot for h in hits[1][1:5]]
    @test [6, 10, 29, 28, 27] == [h.tot for h in hits[1][end-4:end]]
    @test 124 == length(hits[2])
    @test [806455814, 806483369, 806483369] == [h.dom_id for h in hits[2][1:3]]
    @test [809521500, 809526097, 809526097, 809544058, 809544061] == [h.dom_id for h in hits[2][end-4:end]]
    @test [58728018, 58728107, 58729094] == [h.t for h in hits[2][1:3]]
    @test [58729410, 58729741, 58729262] == [h.t for h in hits[2][end-2:end]]
    @test [15, 5, 14, 23, 9] == [h.channel_id for h in hits[2][1:5]]
    @test [17,  5, 18, 24,  8] == [h.channel_id for h in hits[2][end-4:end]]
    @test [27, 24, 21, 17, 22] == [h.tot for h in hits[2][1:5]]
    @test [21, 23, 25, 27, 27] == [h.tot for h in hits[2][end-4:end]]
    @test 78 == length(hits[3])
    @test [806451572, 806483369, 806483369] == [h.dom_id for h in hits[3][1:3]]
    @test [809526097, 809526097, 809526097, 809544058, 809544061] == [h.dom_id for h in hits[3][end-4:end]]
    @test [63512204, 63511134, 63512493] == [h.t for h in hits[3][1:3]]
    @test [63511894, 63511798, 63512892] == [h.t for h in hits[3][end-2:end]]
    @test [4, 9, 5, 17, 20] == [h.channel_id for h in hits[3][1:5]]
    @test [5,  7, 24, 23, 10] == [h.channel_id for h in hits[3][end-4:end]]
    @test [26, 29, 30, 23, 30] == [h.tot for h in hits[3][1:5]]
    @test [28, 11, 27, 24, 23] == [h.tot for h in hits[3][end-4:end]]

    @test 808447186 == f.online.events[end].triggered_hits[1].dom_id

    thits = f.online.events.triggered_hits
    @test 3 == length(thits)
    @test 18 == length(thits[1])
    @test 53 == length(thits[2])
    @test 9 == length(thits[3])

    headers = f.online.events.headers
    @test length(headers) == 3
    for header in headers
        @test header.run == 6633
        @test header.detector_id == 44
        @test header.t.s == 0x5dc6018c
    end
    @test headers[1].frame_index == 127
    @test headers[2].frame_index == 127
    @test headers[3].frame_index == 129
    @test headers[1].t.ns == 700000000
    @test headers[2].t.ns == 700000000
    @test headers[3].t.ns == 900000000
    @test headers[1].trigger_counter == 0
    @test headers[2].trigger_counter == 1
    @test headers[3].trigger_counter == 0
    @test headers[1].trigger_mask == 22
    @test headers[2].trigger_mask == 22
    @test headers[3].trigger_mask == 4
    @test headers[1].overlays == 6
    @test headers[2].overlays == 21
    @test headers[3].overlays == 0

    n_events = Threads.Atomic{Int}(0)
    n_total_hits = Threads.Atomic{Int}(0)
    Threads.@threads for event in f.online.events
        Threads.atomic_add!(n_events, 1)
        n_hits = 0
        for hit in event.snapshot_hits
            n_hits += 1
        end
        Threads.atomic_add!(n_total_hits, n_hits)
    end
    @test 3 == n_events[]
    @test 298 == n_total_hits[]

    events = []
    for event in f.online.events
        push!(events, event)
    end

    @test 3 == length(events)
    @test length(f.online.events.snapshot_hits[1]) == length(events[1].snapshot_hits)
    @test length(f.online.events.triggered_hits[1]) == length(events[1].triggered_hits)
    @test f.online.events.headers[3].frame_index == events[3].header.frame_index

    events = []
    for event in f.online.events[1:2]
        push!(events, event)
    end

    @test 2 == length(events)

    s = f.online.summaryslices
    @test 64 == length(s[1].frames)
    @test 66 == length(s[2].frames)
    @test 68 == length(s[3].frames)
    @test 44 == s[1].header.detector_id == s[2].header.detector_id == s[3].header.detector_id

    @test 68 == length(s[end].frames)

    module_values = Dict(
        808981510 => (fifo = true),
        808981523 => (fifo = false),
    )
    det = Detector(DETX_44)
    module_ids = Set(keys(det.modules))
    for (s_idx, s) ∈ enumerate(f.online.summaryslices)
        for (f_idx, frame) in enumerate(s.frames)
            @test frame.dom_id ∈ module_ids
        end
    end

    n_frames = Threads.Atomic{Int}(0)
    n_pmts = Threads.Atomic{Int}(0)
    n_total_pmt_rate = Threads.Atomic{Float64}(0.0)
    Threads.@threads for s in f.online.summaryslices
        for f in s.frames
            rates = pmtrates(f)
            Threads.atomic_add!(n_total_pmt_rate, sum(rates))
            Threads.atomic_add!(n_pmts, length(rates))
        end
    end
    @test 57008.977876930316 ≈ n_total_pmt_rate[] / n_pmts[]

    close(f)
end
