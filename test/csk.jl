using KM3io
using KM3NeTTestData
using Test

const CSK_FILE = datapath("daq", "clb_acoustics.csk")

@testset "CLB CSK Iterate" begin
    for dg in KM3io.CSK(open(CSK_FILE))
        display(dg)
    end
end

@testset "CLB CSK First Datagrams" begin
    f = open(CSK_FILE)

    # first UDP datagram has no info word

    dg = read(f, KM3io.AbstractCLBDatagram)
    @test 7 == dg.header.udp_sequence_number
    @test KM3io.value(KM3io.CLBAcousticData) == dg.header.data_type
    @test 808951763 == dg.header.dom_id
    @test 1706783280 == dg.header.s
    @test 18750000 == dg.header.ns
    @test 3221225472 == dg.header.dom_status1
    @test 0 == dg.header.dom_status2
    @test 0 == dg.header.dom_status3
    @test 0 == dg.header.dom_status4
    @test false === KM3io.hasinfoword(dg)

    # second UDP datagram has no info word either

    dg = read(f, KM3io.AbstractCLBDatagram)
    @test 8 == dg.header.udp_sequence_number
    @test KM3io.value(KM3io.CLBAcousticData) == dg.header.data_type
    @test 808951763 == dg.header.dom_id
    @test 1706783280 == dg.header.s
    @test 18750000 == dg.header.ns
    @test 3221225472 == dg.header.dom_status1
    @test 0 == dg.header.dom_status2
    @test 0 == dg.header.dom_status3
    @test 0 == dg.header.dom_status4
    @test false === KM3io.hasinfoword(dg)
    # we can not call some methods on a datagram
    # that does not have an info word (aka that is not a CLBDataWithInfo
    @test_throws ErrorException 25 == dg.samplingRate(dg)

    # third one finally has an info word

    dg = read(f, KM3io.AbstractCLBDatagram)
    @test 0 == dg.header.udp_sequence_number
    @test KM3io.value(KM3io.CLBAcousticData) == dg.header.data_type
    @test 808951763 == dg.header.dom_id
    @test 1706783280 == dg.header.s
    @test 25000000 == dg.header.ns
    @test 3221225472 == dg.header.dom_status1
    @test 0 == dg.header.dom_status2
    @test 0 == dg.header.dom_status3
    @test 0 == dg.header.dom_status4
    @test 25 == dg.info.sampling_rate
    @test true === KM3io.hasinfoword(dg)
    @test 195312 == KM3io.samplingRate(dg)
    @test 24 == KM3io.amplitudeResolution(dg)
    @test 1 == KM3io.channel(dg)
    @test 222 == dg.info.ns
    @test 3901 == length(KM3io.audiowords(dg))
    close(f)
end

