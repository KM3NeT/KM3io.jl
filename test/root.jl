using KM3io
import UnROOT
using KM3NeTTestData
using Dates
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

    # start_at
    tape = OfflineEventTape([datapath("offline", "numucc.root"), datapath("offline", "km3net_offline.root")])
    tape.start_at = (2, 5)
    events = collect(tape)
    @test 6 == length(events)
    @test length(ROOTFile(tape.sources[2]).offline[5].hits) == length(events[1].hits)

    sources = [
        datapath("offline", "km3net_offline.root"),
        datapath("offline", "numucc.root"),
        datapath("online", "km3net_online.root"),
        datapath("offline", "muon_cc_events.root")
    ]
    tape = OfflineEventTape(sources)
    tape.start_at = (3, 1)  # will be the online file with no offline tree and events
    events = collect(tape)
    # it should jump to the next file when iterating
    f = ROOTFile(sources[4])
    @test length(f.offline) == length(events)
    @test events[1] == f.offline[1]

    tape.start_at = (9999, 9999)
    @test 0 == length(collect(tape))

    seek(tape, 4)
    @test (1, 4) == position(tape)
    seek(tape, 13)
    @test (2, 3) == position(tape)
    seek(tape, 24)
    @test (4, 4) == position(tape)

    # seek by date
    tape = OfflineEventTape([datapath("offline", "numucc.root"), datapath("offline", "km3net_offline.root")])
    date = DateTime("2019-08-29T00:00:20.100")
    seek(tape, date)
    @test (2, 3) == position(tape)
    @test DateTime(ROOTFile(tape.sources[2]).offline[2]) <= date <= DateTime(ROOTFile(tape.sources[2]).offline[3])
    events = collect(tape)
    @test 8 == length(events)
    @test date <= DateTime(events[1])

    date = DateTime("1985-06-29T07:20:00.000")
    seek(tape, date)
    @test (2, 1) == position(tape)
    @test DateTime(ROOTFile(tape.sources[1]).offline[end]) <= date <= DateTime(ROOTFile(tape.sources[2]).offline[1])
    events = collect(tape)
    @test 10 == length(events)
    @test date <= DateTime(events[1])

    date = DateTime("2025-06-29T07:20:00.000")
    seek(tape, date)
    @test (length(tape.sources)+1, 1) == position(tape)
    @test 0 == length(collect(tape))
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

@testset "Acoustics Event File" begin
    f = AcousticsEventFile(datapath("acoustics", "KM3NeT_00000267_00024724.acoustic-events_A_2.0.0.root"))
    @test 9 == f[1].id
    @test 267 == f[1].det_id
    @test 3 == f[1].overlays
    @test 0 == f[1].counter
    @test 23 == f[end].id
    @test 1427 == f[end].counter
    @test 518 == length(f)
    @test 403 == length(f[1])
    @test 403 == length(f[1].transmissions)
    @test 401 == length(f[end])
    @test 5 == length(f[5:9])
    @test 808957378 == f[1].transmissions[1].id
    @test 24724 == f[1].transmissions[1].run
    @test 4707.0 == f[1].transmissions[1].q
    @test 0.0 == f[1].transmissions[1].w
    @test isapprox(1.7559723249875731e9, f[1].transmissions[1].toa)
    @test isapprox(1.755972324518772e9, f[1].transmissions[1].toe)

    n = 0
    for event in f
        n += length(event)
    end
    @test 208111 == n
end
