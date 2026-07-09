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
    @test 9.427e37 == f.offline[2].w2list[0]
    @test 9.427e37 == f.offline[2].w2list[KM3io.W2LIST_GENHEN.W2LIST_GENHEN_GLOBAL_GEN_WEIGHT]
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

    # TODO: this needs a better test, with a file where status is not always 0
    n_status_sum = 0
    for event in f.offline
        for track in event.trks
            n_status_sum += track.status
        end
    end
    @test 0 == n_status_sum


    close(f)
end

@testset "Skipping offline branches" begin
    f = ROOTFile(datapath("offline", "numucc.root"))
    full = f.offline[1]
    @test !isempty(full.hits)          # sanity: non-empty in a full read
    @test !isempty(full.mc_hits)
    @test !isempty(full.trks)

    v = eachevent(f.offline; skip=(:hits, :mc_hits))
    @test length(v) == length(f.offline)
    @test eltype(v) == Evt

    e = v[1]
    @test isempty(e.hits)              # skipped -> empty
    @test isempty(e.mc_hits)
    @test e.trks == full.trks          # untouched -> identical to full read
    @test e.mc_trks == full.mc_trks
    @test e.id == full.id
    @test e.w2list == full.w2list

    # a single Symbol is accepted too
    @test isempty(eachevent(f.offline; skip=:trks)[1].trks)

    # everything skipped
    for ev ∈ eachevent(f.offline; skip=(:hits, :mc_hits, :trks, :mc_trks))
        @test isempty(ev.hits) && isempty(ev.mc_hits) && isempty(ev.trks) && isempty(ev.mc_trks)
    end

    # a full read from the same tree still works
    @test !isempty(f.offline[1].hits)

    # unknown branch names raise
    @test_throws ArgumentError eachevent(f.offline; skip=(:hitz,))
    @test_throws ArgumentError eachevent(f.offline; skip=:bar)

    # threaded iteration with skipping
    n = Threads.Atomic{Int}(0)
    Threads.@threads for ev ∈ eachevent(f.offline; skip=(:hits, :mc_hits))
        @assert isempty(ev.hits) && isempty(ev.mc_hits)
        Threads.atomic_add!(n, 1)
    end
    @test n[] == length(f.offline)

    # `only` keeps the named branches and skips the rest (complement of `skip`)
    o = eachevent(f.offline; only=:mc_trks)[1]
    @test isempty(o.hits) && isempty(o.mc_hits) && isempty(o.trks)
    @test o.mc_trks == full.mc_trks
    o2 = eachevent(f.offline; only=(:hits, :trks))[1]
    @test o2.hits == full.hits && o2.trks == full.trks
    @test isempty(o2.mc_hits) && isempty(o2.mc_trks)
    # only=() keeps nothing, i.e. skips everything
    oall = eachevent(f.offline; only=())[1]
    @test isempty(oall.hits) && isempty(oall.mc_hits) && isempty(oall.trks) && isempty(oall.mc_trks)
    # skip and only together, or an unknown branch, raise
    @test_throws ArgumentError eachevent(f.offline; skip=(:hits,), only=(:mc_trks,))
    @test_throws ArgumentError eachevent(f.offline; only=(:bogus,))

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
    for (event_a, (event_b, header_b)) in zip(reference_events, tape_events)
        @test event_a == event_b
    end
    tape_events = collect(tape)  # test twice because of caching
    for (event_a, (event_b, header_b)) in zip(reference_events, tape_events)
        @test event_a == event_b
    end

    # start_at
    tape = OfflineEventTape([datapath("offline", "numucc.root"), datapath("offline", "km3net_offline.root")])
    tape.start_at = (2, 5)
    entries = collect(tape)
    @test 6 == length(entries)
    @test length(ROOTFile(tape.sources[2]).offline[5].hits) == length(entries[1].event.hits)

    sources = [
        datapath("offline", "km3net_offline.root"),
        datapath("offline", "numucc.root"),
        datapath("online", "km3net_online.root"),
        datapath("offline", "muon_cc_events.root")
    ]
    tape = OfflineEventTape(sources)
    tape.start_at = (3, 1)  # will be the online file with no offline tree and events
    entries = collect(tape)
    # it should jump to the next file when iterating
    f = ROOTFile(sources[4])
    @test length(f.offline) == length(entries)
    @test entries[1].event == f.offline[1]

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
    entries = collect(tape)
    @test 8 == length(entries)
    @test date <= DateTime(entries[1].event)

    date = DateTime("1985-06-29T07:20:00.000")
    seek(tape, date)
    @test (2, 1) == position(tape)
    @test DateTime(ROOTFile(tape.sources[1]).offline[end]) <= date <= DateTime(ROOTFile(tape.sources[2]).offline[1])
    entries = collect(tape)
    @test 10 == length(entries)
    @test date <= DateTime(entries[1].event)

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
        endswith(fpath, ".root") || continue  # skip non-ROOT companion files (e.g. .md)
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

    # eachevent wrapper mirrors iterating f.online.events
    v = eachevent(f.online)
    @test length(v) == length(f.online.events)
    @test eltype(v) == KM3io.DAQEvent
    @test [e.header.frame_index for e ∈ v] == [e.header.frame_index for e ∈ f.online.events]
    @test length(v[1].snapshot_hits) == length(f.online.events[1].snapshot_hits)
    n = Threads.Atomic{Int}(0)
    Threads.@threads for e ∈ eachevent(f.online)
        Threads.atomic_add!(n, 1)
    end
    @test n[] == length(f.online.events)

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

@testset "Timeslices" begin
    f = ROOTFile(ONLINEFILE)

    @test hastimeslices(f)
    @test hastimeslices(f, :L1)
    @test hastimeslices(f, :SN)
    @test !hastimeslices(f, :L0)
    @test !hastimeslices(f, :L2)
    @test hasl1timeslices(f)
    @test hassntimeslices(f)
    @test !hasl0timeslices(f)
    @test !hasl2timeslices(f)

    # absent/empty streams are `nothing`
    @test f.online.timeslices.L0 === nothing
    @test f.online.timeslices.L2 === nothing

    L1 = f.online.timeslices.L1
    @test 3 == length(L1)

    ts = L1[1]
    @test :L1 == ts.stream
    @test 44 == ts.header.detector_id
    @test 6633 == ts.header.run
    @test 512 == ts.header.frame_index
    @test 1573257651 == ts.header.t.s
    @test 200000000 == ts.header.t.ns  # 12500000 cycles * 16 ns

    @test 69 == length(ts.frames)
    @test 49243 == sum(length(frame.hits) for frame in ts.frames)

    frame = ts.frames[1]
    @test 806451572 == frame.module_id
    @test 984 == length(frame.hits)
    @test 1441815 == frame.daq
    @test 0x80000000 == frame.status
    @test 0x80000000 == frame.fifo

    # hits are lightweight TimesliceHits which do not carry the module id
    @test all(h -> h isa TimesliceHit, frame.hits)
    @test !hasfield(TimesliceHit, :dom_id)
    @test [9, 28, 4, 4] == [h.channel_id for h in frame.hits[1:4]]
    @test [486480, 486490, 709517, 709526] == [h.t for h in frame.hits[1:4]]
    @test [27, 24, 5, 7] == [h.tot for h in frame.hits[1:4]]

    @test 806455814 == ts.frames[2].module_id
    @test 1004 == length(ts.frames[2].hits)
    @test 809544061 == ts.frames[end].module_id
    @test 726 == length(ts.frames[end].hits)

    # range and iteration
    @test 2 == length(L1[1:2])
    collected = Timeslice[]
    for t in L1
        push!(collected, t)
    end
    @test 3 == length(collected)
    @test 69 == length(collected[1].frames)

    # SN stream (supernova), with much fewer hits and even empty frames
    SN = f.online.timeslices.SN
    @test 3 == length(SN)
    sn = SN[1]
    @test :SN == sn.stream
    @test 126 == sn.header.frame_index
    @test 64 == length(sn.frames)
    @test 98 == sum(length(frame.hits) for frame in sn.frames)
    @test 806451572 == sn.frames[1].module_id
    @test 4 == length(sn.frames[1].hits)
    @test 0 == length(sn.frames[2].hits)  # empty frame
    @test [0, 1, 2, 5] == [h.channel_id for h in sn.frames[1].hits]
    @test [65829267, 65829259, 65829263, 65829271] == [h.t for h in sn.frames[1].hits]

    # a super frame can be calibrated using the module id it carries
    det = Detector(DETX_44)
    chits = calibratetime(det, frame)
    @test length(frame.hits) == length(chits)
    @test all(ch -> ch isa CalibratedSnapshotHit, chits)
    @test all(ch -> ch.dom_id == frame.module_id, chits)
    pmt = getmodule(det, frame.module_id)[frame.hits[1].channel_id]
    @test chits[1].t == frame.hits[1].t + pmt.t₀
    xhits = calibrate(det, frame)
    @test length(frame.hits) == length(xhits)
    @test all(xh -> xh isa XCalibratedHit, xhits)
    @test all(xh -> xh.dom_id == frame.module_id, xhits)

    # threaded access over all frames of all timeslices
    n_hits = Threads.Atomic{Int}(0)
    Threads.@threads for t in L1
        for frame in t.frames
            Threads.atomic_add!(n_hits, length(frame.hits))
        end
    end
    @test n_hits[] > 0

    close(f)
end

# Dedicated per-stream timeslice files using the member-wise (low split level)
# layout, as opposed to the fully split layout of `km3net_online.root` above.
@testset "Timeslices (per-stream, member-wise)" begin
    f = ROOTFile(datapath("online", "KM3NeT_00000267_00025291_L1.root"))
    @test hastimeslices(f, :L1)
    @test !hastimeslices(f, :SN)
    @test hasl1timeslices(f)
    @test !hasl0timeslices(f)
    @test !hasl2timeslices(f)
    @test !hassntimeslices(f)
    @test f.online.timeslices.L0 === nothing
    @test f.online.timeslices.L2 === nothing
    @test f.online.timeslices.SN === nothing

    L1 = f.online.timeslices.L1
    @test 3 == length(L1)
    ts = L1[1]
    @test 267 == ts.header.detector_id
    @test 25291 == ts.header.run
    @test 5057 == ts.header.frame_index
    @test 453 == length(ts.frames)
    @test 167499 == sum(length(frame.hits) for frame in ts.frames)

    frame = ts.frames[1]
    @test 806455816 == frame.module_id
    @test 432 == length(frame.hits)
    @test 1835037 == frame.daq
    @test 0x80000000 == frame.status
    @test [20, 20, 18, 18] == [h.channel_id for h in frame.hits[1:4]]
    @test [97069, 97078, 690216, 690224] == [h.t for h in frame.hits[1:4]]
    @test [4, 4, 7, 19] == [h.tot for h in frame.hits[1:4]]

    @test 5058 == L1[2].header.frame_index
    @test 168414 == sum(length(fr.hits) for fr in L1[2].frames)
    @test 5059 == L1[3].header.frame_index
    @test 167420 == sum(length(fr.hits) for fr in L1[3].frames)
    close(f)

    f = ROOTFile(datapath("online", "KM3NeT_00000267_00025291_SN.root"))
    @test hastimeslices(f, :SN)
    @test !hastimeslices(f, :L1)
    @test hassntimeslices(f)
    @test !hasl1timeslices(f)
    SN = f.online.timeslices.SN
    @test 100 == length(SN)

    @test 2087 == SN[1].header.frame_index
    @test 0 == length(SN[1].frames)  # empty supernova timeslice

    sn = SN[51]
    @test 2137 == sn.header.frame_index
    @test 454 == length(sn.frames)
    @test 1084 == sum(length(frame.hits) for frame in sn.frames)
    # frames may be empty; the first non-empty one carries the hits
    nonempty = sn.frames[findfirst(fr -> !isempty(fr.hits), sn.frames)]
    @test 806476519 == nonempty.module_id
    @test 4 == length(nonempty.hits)
    @test [12, 14, 15, 19] == [h.channel_id for h in nonempty.hits]
    @test [62757457, 62757456, 62757463, 62757457] == [h.t for h in nonempty.hits]

    @test 2186 == SN[100].header.frame_index
    @test 1068 == sum(length(fr.hits) for fr in SN[100].frames)
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

@testset "DST files" begin
    # v6 DST: full schema (sum_mc_evt, sum_casc, headerTree, dst_history, ...)
    f = ROOTFile(datapath("dst", "mcv6.gsg_numu-CCHEDIS_1e2-1e8GeV.sirene.jte.jchain.aashower.dst.bdt_trk.bdt_casc.10events.root"))
    @test f.dst isa DSTTree
    @test f.offline isa KM3io.OfflineTree   # the E tree is parsed by OfflineTree
    @test 10 == length(f.dst)
    @test eltype(f.dst) === DSTEvent

    e = f.dst[1]
    @test e isa DSTEvent

    # All top-level T-tree branches are exposed dynamically
    @test (:sum_mc_evt, :sum_mc_trks, :sum_mc_hits, :sum_hits, :sum_trig_hits,
           :sum_jpptrack, :sum_casc, :crkv_hits, :bdt_trk, :bdt_casc) ⊆ propertynames(e)

    # Composite branches return DSTBranchView objects (lazy NamedTuple-like)
    @test e.sum_mc_evt isa KM3io.DSTBranchView
    @test 41 == e.sum_mc_evt.MC_run
    @test 128_000_000 == e.sum_mc_evt.n_gen

    @test e.sum_mc_trks isa KM3io.DSTBranchView
    @test 42 == e.sum_mc_trks.ntrks
    # The highest-energy MC muon is flattened into the same view
    @test e.sum_mc_trks.Etot ≈ e.sum_mc_trks.tmuon_E

    @test 1086 == e.sum_mc_hits.nhits
    @test 6629 == e.sum_hits.nhits
    @test 413  == e.sum_trig_hits.nhits

    # crkv_hits members were originally "crkv_hits.X[3]"; should be cleaned to just X
    @test issubset(
        (:nhits, :nhits_20m, :nhits_50m, :nhits_100m, :nhits_200m,
         :sumtot, :closest, :furthest),
        propertynames(e.crkv_hits))
    @test 6 == length(e.crkv_hits.nhits)

    @test 819 == e.sum_casc.nhits_aashower
    @test 3 == length(e.sum_casc.inertia_tensor_eigenvalues)

    @test 12 == e.sum_jpptrack.ntrks

    # Scalar top-level branches return their value directly (not wrapped in a NamedTuple)
    @test e.bdt_trk isa AbstractVector{<:Real}   # bdt_trk happens to be array-valued per event
    @test e.bdt_casc isa AbstractVector{<:Real}

    # Iteration and indexing
    @test 10 == count(_ -> true, f.dst)
    @test 3 == length(f.dst[2:4])

    # Raw branch access
    @test [ev.sum_mc_evt.weight for ev ∈ f.dst] == f.dst["sum_mc_evt/weight", :]

    # headerTree (optional)
    @test f.dst.run_headers isa DSTRunHeaders
    @test 1 == length(f.dst.run_headers)
    @test f.dst.run_headers.headers[1] isa KM3io.MCHeader

    # dst_history (optional)
    @test f.dst.history isa DSTHistory
    @test !isempty(f.dst.history.input_files)
    @test !isempty(f.dst.history.command_line)
    close(f)

    # v5.1 DST: minimal schema (no sum_mc_evt, no sum_casc, no headerTree, no dst_history)
    f = ROOTFile(datapath("dst", "mcv5.1.km3_numuCC.ALL.dst.bdt.10events.root"))
    @test f.dst isa DSTTree
    @test 10 == length(f.dst)
    e = f.dst[1]
    @test :sum_mc_evt ∉ propertynames(e)   # not in the file
    @test :sum_casc   ∉ propertynames(e)
    @test :sum_jgandalf ∈ propertynames(e)
    @test :bdt        ∈ propertynames(e)   # scalar bare-bdt branch
    @test e.sum_mc_trks.ntrks isa Integer
    @test e.sum_hits.nhits    isa Integer
    @test isnothing(f.dst.run_headers)
    @test isnothing(f.dst.history)
    close(f)

    # Non-DST files must not get a DSTTree wrapper
    @test isnothing(ROOTFile(OFFLINEFILE).dst)
    @test isnothing(ROOTFile(ONLINEFILE).dst)

    # Registry / lookup helpers
    @test DST_BRANCHES isa Dict
    @test occursin("MC", describe_dst_branch("sum_mc_evt"))
    @test ismissing(describe_dst_branch("not_a_known_branch"))
end

@testset "Meta data" begin
    # single application
    f = ROOTFile(datapath("offline", "numucc.root"))
    @test f.meta isa Vector{MetaData}
    @test 1 == length(f.meta)
    m = f.meta[1]
    @test m isa MetaData
    @test "JConvertEvt" == m.application
    @test "12.1.0" == m.revision
    @test "5.34/38" == m.root
    @test "KM3NET" == m.namespace
    @test occursin("JConvertEvt -n 10", m.command)
    @test occursin("Linux", m.system)
    @test DateTime(2019, 12, 10, 13, 59, 52) == m.datetime
    # `system` is uname output, decomposed
    @test "Linux" == m.sysname
    @test "cca007" == m.hostname
    @test "3.10.0-1062.9.1.el7.x86_64" == m.kernel_release
    @test "x86_64" == m.machine
    # kernel build time, not the processing time
    @test DateTime(2019, 12, 6, 15, 49, 49) == m.kernel_datetime
    @test m.kernel_datetime != m.datetime
    # raw key-value access
    @test "JConvertEvt" == m["application"]
    @test "12.1.0" == m["GIT"]
    @test haskey(m, "GIT")
    @test !haskey(m, "SVN")
    @test "fallback" == get(m, "SVN", "fallback")
    @test Set(keys(m)) == Set(["application", "GIT", "ROOT", "namespace", "command", "system"])
    @test_throws KeyError m["nope"]
    close(f)

    # full processing chain, ordered by processing step
    f = ROOTFile(datapath("offline", "mcv6.0.gsg_muon_highE-CC_50-500GeV.km3sim.jterbr00008357.jorcarec.aanet.905.root"))
    @test 8 == length(f.meta)
    @test ["JConvertEvt", "JMuonEnergy", "JMuonStart", "JMuonGandalf",
           "JMuonStart", "JMuonSimplex", "JMuonPrefit", "JTriggerEfficiency"] ==
        [m.application for m in f.meta]
    # the two JMuonStart steps are distinct invocations
    @test f.meta[3].command != f.meta[5].command
    @test all(m -> m.revision == "14.1.0", f.meta)
    # all entries carry the timestamp of the step which wrote the file
    @test [DateTime(2021, 4, 14, 10, 36, 23)] == unique(m.datetime for m in f.meta)
    close(f)

    # online file, `system` holds a full "uname -a"
    f = ROOTFile(datapath("online", "km3net_online.root"))
    @test 1 == length(f.meta)
    m = f.meta[1]
    @test "JDataWriter" == m.application
    @test DateTime(2019, 11, 17, 0, 8, 51) == m.datetime
    @test "antorcadaq1.in2p3.fr" == m.hostname
    @test "x86_64" == m.machine                 # not the trailing "GNU/Linux"
    @test DateTime(2014, 12, 16, 14, 29, 22) == m.kernel_datetime
    close(f)

    # no meta data
    f = ROOTFile(OFFLINEFILE)
    @test f.meta isa Vector{MetaData}
    @test isempty(f.meta)
    close(f)

    # only the first '=' of a line splits key and value
    raw = KM3io._parse_jmeta("application=JFoo\ncommand=A -@ \"x = 1;\"\nGIT=1.2.3\n")
    @test "JFoo" == raw["application"]
    @test "A -@ \"x = 1;\"" == raw["command"]
    @test "1.2.3" == raw["GIT"]
    md = MetaData(raw)
    @test "JFoo" == md.application
    @test "1.2.3" == md.revision

    # empty value, no separator, blank lines
    raw = KM3io._parse_jmeta("a=\nnoseparator\n\nb=1")
    @test "" == raw["a"]
    @test "1" == raw["b"]
    @test !haskey(raw, "noseparator")

    # legacy files use SVN instead of GIT
    @test "9.9" == MetaData(Dict("application" => "JBar", "SVN" => "9.9")).revision
    # missing entries degrade instead of throwing
    @test "" == MetaData(Dict("application" => "JBar")).revision
    @test ismissing(MetaData(Dict("application" => "JBar")).datetime)

    # cross-checked against ROOT's own TDatime
    @test DateTime(2021, 4, 14, 10, 36, 23) == KM3io._datime2datetime(1763485975)
    @test DateTime(2019, 12, 10, 13, 59, 52) == KM3io._datime2datetime(1662312180)
    @test ismissing(KM3io._datime2datetime(0))          # month/day are 0 -> invalid

    # uname decomposition
    s = KM3io._parse_system("Linux cca007 3.10.0-1062.9.1.el7.x86_64 #1 SMP Fri Dec 6 15:49:49 UTC 2019 x86_64")
    @test ("Linux", "cca007", "x86_64") == (s.sysname, s.hostname, s.machine)
    @test DateTime(2019, 12, 6, 15, 49, 49) == s.kernel_datetime
    # "uname -a" layout: machine is the token after the year, not the last one
    s = KM3io._parse_system("Linux w1 2.6.32.x86_64 #1 SMP Tue Dec 16 14:29:22 CST 2014 x86_64 x86_64 x86_64 GNU/Linux")
    @test "x86_64" == s.machine
    @test DateTime(2014, 12, 16, 14, 29, 22) == s.kernel_datetime
    # kernels without a timezone token, and PREEMPT_DYNAMIC style versions
    @test DateTime(2025, 9, 8, 12, 15, 13) ==
        KM3io._parse_system("Linux h 5.14.0 #1 SMP PREEMPT_DYNAMIC Mon Sep 8 12:15:13 EDT 2025 x86_64").kernel_datetime
    @test DateTime(2022, 8, 10, 13, 42, 3) ==
        KM3io._parse_system("Linux h 5.4.0-125-generic #141-Ubuntu SMP Wed Aug 10 13:42:03 2022 x86_64").kernel_datetime
    # degrade gracefully
    for bad in ("", "Linux", "Linux host 1.2.3", "no date here at all")
        p = KM3io._parse_system(bad)
        @test ismissing(p.kernel_datetime)
        @test "" == p.machine
    end
    @test "" == KM3io._parse_system("").hostname
    @test ismissing(MetaData(Dict("application" => "JX")).kernel_datetime)

    # printmeta
    f = ROOTFile(datapath("offline", "numucc.root"))
    out = sprint(printmeta, f)
    @test occursin("Meta data (1 processing step)", out)
    @test occursin("[1] JConvertEvt", out)
    @test occursin("revision:  12.1.0", out)
    @test occursin("datetime:  2019-12-10T13:59:52", out)
    @test out == sprint(printmeta, f.meta)      # ROOTFile and its meta vector agree
    close(f)

    f = ROOTFile(datapath("offline", "mcv6.0.gsg_muon_highE-CC_50-500GeV.km3sim.jterbr00008357.jorcarec.aanet.905.root"))
    out = sprint(printmeta, f)
    @test occursin("Meta data (8 processing steps, oldest first)", out)
    @test occursin("[8] JTriggerEfficiency", out)
    close(f)

    @test "No meta data.\n" == sprint(printmeta, MetaData[])
    @test occursin("[1] JBar", sprint(printmeta, MetaData(Dict("application" => "JBar"))))
end
