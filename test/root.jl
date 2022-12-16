using KM3io
using Test


const DETX = joinpath(@__DIR__, "samples", "v3.detx")
const ONLINEFILE = joinpath(@__DIR__, "samples", "km3net_online.root")
const OFFLINEFILE = joinpath(@__DIR__, "samples", "km3net_offline.root")
const IO_EVT = joinpath(@__DIR__, "samples", "IO_EVT.dat")


@testset "calibration" begin
    calib = Calibration(DETX)

    @test 23 == calib.det_id
    @test 6 == length(values(calib.pos))
    @test 6 == length(values(calib.dir))
    @test 6 == length(values(calib.t0))
    @test 6 == length(values(calib.du))
    @test 6 == length(values(calib.floor))
    @test 6 == length(values(calib.omkeys))
    @test 23.9 ≈ calib.max_z
    @test 2 == calib.n_dus
    @test 3.6 ≈ calib.pos[3][2].z

    @test 4 == omkey2domid(calib, 2, 1)
    @test 4 == omkey2domid(calib, OMKey(2, 1))
end

@testset "km3net online files" begin
    f = NeRCA.OnlineFile(ONLINEFILE)
    hits = NeRCA.read_snapshot_hits(f)
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

    thits = NeRCA.read_triggered_hits(f)
    @test 3 == length(thits)
    @test 18 == length(thits[1])
    @test 53 == length(thits[2])
    @test 9 == length(thits[3])

    headers = NeRCA.read_headers(f)
    @test length(headers) == 3
    for header in headers
        @test header.run == 6633
        @test header.detector_id == 44
        @test header.UTC_seconds == 0x5dc6018c
    end
    @test headers[1].frame_index == 127
    @test headers[2].frame_index == 127
    @test headers[3].frame_index == 129
    @test headers[1].UTC_16nanosecondcycles == 0x029b9270
    @test headers[2].UTC_16nanosecondcycles == 0x029b9270
    @test headers[3].UTC_16nanosecondcycles == 0x035a4e90
    @test headers[1].trigger_counter == 0
    @test headers[2].trigger_counter == 1
    @test headers[3].trigger_counter == 0
    @test headers[1].trigger_mask == 22
    @test headers[2].trigger_mask == 22
    @test headers[3].trigger_mask == 4
    @test headers[1].overlays == 6
    @test headers[2].overlays == 21
    @test headers[3].overlays == 0
end


@testset "DAQ readout" begin
    f = open(IO_EVT)
    daqevent = read(f, NeRCA.DAQEvent; legacy=true)
    @test 49 == daqevent.det_id
    @test 8142 == daqevent.run_id
    @test 107050 == daqevent.timeslice_id
    @test 1591693105 == daqevent.timestamp
    @test 0 == daqevent.ticks
    @test 9789 == daqevent.trigger_counter
    @test 2 == daqevent.trigger_mask
    @test 0 == daqevent.overlays
    @test 6 == daqevent.n_triggered_hits
    @test 6 == length(daqevent.triggered_hits)
    @test 106 == daqevent.n_hits
    @test 106 == length(daqevent.hits)
    @test NeRCA.is3dshower(daqevent)
    @test !NeRCA.ismxshower(daqevent)
    @test !NeRCA.is3dmuon(daqevent)
    @test !NeRCA.isnb(daqevent)
    close(f)
end
