using KM3io
import UnROOT
using KM3NeTTestData
using Test

const OSCFILE = datapath("oscillations", "ORCA6_433kt-y_opendata_v0.4_testdata.root")

@testset "Oscillations open data files" begin
    f = OSCFile(OSCFILE)
    nu = f.osc_opendata_nu
    data = f.osc_opendata_data
    muons = f.osc_opendata_muons
    @test 59301 == length(nu)
    @test 1 == nu[1].AnaClass
    @test 1 == nu[1].Ct_reco_bin
    @test 18 == nu[1].Ct_true_bin
    @test 10 == nu[1].E_reco_bin
    @test 30 == nu[1].E_true_bin
    @test -12 == nu[1].Flav
    @test 1 == nu[1].IsCC
    @test isapprox(nu[1].W, 52.25311519561337)
    @test isapprox(nu[1].Werr, 2730.388047646041)

    @test 106 == length(data)
    @test 1 == data[1].AnaClass
    @test 6 == data[1].Ct_reco_bin
    @test 2 == data[1].E_reco_bin
    @test isapprox(data[1].W, 2.0)

    @test 99 == length(muons)
    @test 1 == muons[1].AnaClass
    @test 4 == muons[1].Ct_reco_bin
    @test 1 == muons[1].E_reco_bin
    @test isapprox(data[1].W, 2.0)

    close(f)
end