@testset "DAQ readout" begin
    f = open(IO_EVT_LEGACY)
    daqevent = read(f, KM3io.DAQEvent; legacy=true)
    @test 7 == daqevent.header.detector_id
    @test 139 == daqevent.header.run
    @test 5443 == daqevent.header.frame_index
    @test 1449571426 == daqevent.header.t.s
    @test 300000000 == daqevent.header.t.ns
    @test 184 == daqevent.header.trigger_counter
    @test 0x0000000000000012 == daqevent.header.trigger_mask
    @test 13 == daqevent.header.overlays
    @test 13 == length(daqevent.triggered_hits)
    @test 28 == length(daqevent.snapshot_hits)
    @test is3dshower(daqevent)
    @test !ismxshower(daqevent)
    @test is3dmuon(daqevent)
    @test !isnb(daqevent)
    close(f)
end
