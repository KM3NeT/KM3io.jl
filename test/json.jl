using KM3io
using JSON
using KM3NeTTestData
using Test


const OFFLINEFILE = datapath("offline", "km3net_offline.root")


@testset "JSON output" begin
    f = ROOTFile(OFFLINEFILE)
    e = f.offline[1]

    outfile = tempname()
    tojson(outfile, e)

    json_evt = JSON.parsefile(outfile)
    json_hits = json_evt["hits"]
    @test 1.5670368182e9 == json_evt["utc_timestamp"]

    bt = bestjppmuon(e)
    json_bt = json_evt["best_track"]
    @test bt.pos.x == json_bt["pos_x"]
    @test bt.pos.y == json_bt["pos_y"]
    @test bt.pos.z == json_bt["pos_z"]
    @test bt.dir.x == json_bt["dir_x"]
    @test bt.dir.y == json_bt["dir_y"]
    @test bt.dir.z == json_bt["dir_z"]
    @test bt.t == json_bt["t"]

    @test 176 == length(json_hits)
    for idx in 1:length(json_hits)
        orig_hit = e.hits[idx]
        json_hit = json_hits[idx]
        @test orig_hit.pos.x == json_hit["pos_x"]
        @test orig_hit.pos.y == json_hit["pos_y"]
        @test orig_hit.pos.z == json_hit["pos_z"]
        @test orig_hit.dir.x == json_hit["dir_x"]
        @test orig_hit.dir.y == json_hit["dir_y"]
        @test orig_hit.dir.z == json_hit["dir_z"]
        @test (orig_hit.trigger_mask > 0) == json_hit["triggered"]
    end


end
