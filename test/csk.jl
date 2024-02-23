using KM3io
using KM3NeTTestData
using Test

const CSK = datapath("daq", "clb_acoustics.csk")

@testset "CLB CSK" begin
        f = open(CSK)

        # first UDP datagram has no info word

        dg = read(f,KM3io.CLBDataGram)
        @test 7 == dg.header.udp_sequence_number
        @test 1413563731 == dg.header.data_type
        @test 808951763 == dg.header.dom_id
        @test 1706783280 == dg.header.s
        @test 18750000== dg.header.ns
        @test 3221225472 == dg.header.dom_status1
        @test 0 == dg.header.dom_status2
        @test 0 == dg.header.dom_status3
        @test 0 == dg.header.dom_status4
        @test dg.info === nothing
        
        # second UDP datagram has no info word either
        
        dg = read(f,KM3io.CLBDataGram)
        @test 8 == dg.header.udp_sequence_number
        @test 1413563731 == dg.header.data_type
        @test 808951763 == dg.header.dom_id
        @test 1706783280 == dg.header.s
        @test 18750000 == dg.header.ns
        @test 3221225472 == dg.header.dom_status1
        @test 0 == dg.header.dom_status2
        @test 0 == dg.header.dom_status3
        @test 0 == dg.header.dom_status4
        @test dg.info === nothing

        # third one finally has an info word
       
        dg = read(f,KM3io.CLBDataGram)
        @test 0 == dg.header.udp_sequence_number
        @test 1413563731 == dg.header.data_type
        @test 808951763 == dg.header.dom_id
        @test 1706783280 == dg.header.s
        @test 25000000 == dg.header.ns
        @test 3221225472 == dg.header.dom_status1
        @test 0 == dg.header.dom_status2
        @test 0 == dg.header.dom_status3
        @test 0 == dg.header.dom_status4
        @test 25 == dg.info.sampling_rate
        @test 195312 == KM3io.samplingRate(dg)
        @test 24 == KM3io.amplitudeResolution(dg)
        @test 1 == KM3io.channel(dg)
        @test 222 == dg.info.ns
        
        close(f)
end
