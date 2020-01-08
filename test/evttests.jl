using KM3io
using Test

const EVTFILE = joinpath(@__DIR__, "data", "testdata.evt")

@testset "evt" begin
    testfile = KM3io.EvtFile(EVTFILE) 
    events = testfile.events
    @test length(events) == 10
    first_event = events[1]
    # HITS
    @test length(first_event.hits) == 4
    # NEUTRINO
    nu = first_event.neutrino
    @test nu.cc
    @test all( isapprox.(nu.bjorken, (0.225275, 0.316002)) )
    @test nu.particle.value == 12
    @test nu.ichannel == 1
    @test all( isapprox.(nu.kin.vtx_pos, Vector([-47.084, -76.701, -85.565])) )
    @test all( isapprox.(nu.kin.dir, Vector([0.545149, 0.398641, -0.737494])) )
end
