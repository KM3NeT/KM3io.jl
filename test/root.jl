using KM3io
using UnROOT
using KM3NeTTestData
using Test


const DETX = datapath("detx", "detx_v3.detx")
const DETX_44 = datapath("detx", "km3net_offline.detx")
const ONLINEFILE = datapath("online", "km3net_online.root")
const OFFLINEFILE = datapath("offline", "km3net_offline.root")
const IO_EVT = datapath("daq", "IO_EVT.dat")
const IO_EVT_LEGACY = datapath("daq", "IO_EVT_legacy.dat")


@testset "KM3NeT online files" begin
    f = OnlineFile(ONLINEFILE)
    hits = f.events.snapshot_hits
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

    thits = f.events.triggered_hits
    @test 3 == length(thits)
    @test 18 == length(thits[1])
    @test 53 == length(thits[2])
    @test 9 == length(thits[3])

    headers = f.events.headers
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

    events = []
    for event in f.events
        push!(events, event)
    end

    @test 3 == length(events)
    @test length(f.events.snapshot_hits[1]) == length(events[1].snapshot_hits)
    @test length(f.events.triggered_hits[1]) == length(events[1].triggered_hits)
    @test f.events.headers[3].frame_index == events[3].header.frame_index

    events = []
    for event in f.events[1:2]
        push!(events, event)
    end

    @test 2 == length(events)

    s = f.summaryslices
    @test 64 == length(s[1].frames)
    @test 66 == length(s[2].frames)
    @test 68 == length(s[3].frames)
    @test 44 == s[1].header.detector_id == s[2].header.detector_id == s[3].header.detector_id

    module_values = Dict(
        808981510: (fifo = true),
        808981523: (fifo = false),
    )
    det = Detector(DETX_44)
    module_ids = Set(keys(det.modules))
    for (s_idx, s) ∈ enumerate(f.summaryslices)
        for (f_idx, frame) in enumerate(s.frames)
            @test frame.dom_id ∈ module_ids
        end
    end
end
