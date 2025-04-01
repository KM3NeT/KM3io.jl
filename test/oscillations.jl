using KM3io
import UnROOT
using KM3NeTTestData
using Test

const OSCFILE = datapath("oscillations", "ORCA6_433kt-y_opendata_v0.5_testdata.root")

@testset "Oscillations open data files" begin
    f = OSCFile(OSCFILE)
    nu = f.osc_opendata_nu
    data = f.osc_opendata_data
    muons = f.osc_opendata_muons
    @test 59360 == length(nu)
    @test 1 == nu[1].AnaClass
    @test 1 == nu[1].Ct_reco_bin
    @test 3 == nu[1].Ct_true_bin
    @test 11 == nu[1].E_reco_bin
    @test 30 == nu[1].E_true_bin
    @test -12 == nu[1].Pdg
    @test 1 == nu[1].IsCC
    @test isapprox(nu[1].W, 725.8889579721612)
    @test isapprox(nu[1].WE, 99699.08425875357)

    @test 92 == length(data)
    @test 1 == data[1].AnaClass
    @test 4 == data[1].Ct_reco_bin
    @test 1 == data[1].E_reco_bin
    @test isapprox(data[1].W, 3.0)

    @test 85 == length(muons)
    @test 1 == muons[1].AnaClass
    @test 7 == muons[1].Ct_reco_bin
    @test 1 == muons[1].E_reco_bin
    @test isapprox(muons[1].W, 0.08825455071391969)
    @test isapprox(muons[1].WE, 0.0009736083957537474)

    close(f)
end