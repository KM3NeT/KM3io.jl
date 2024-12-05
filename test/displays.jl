using Test

using KM3io
using KM3NeTTestData

const ONLINEFILE = datapath("online", "km3net_online.root")
const OFFLINEFILE = datapath("offline", "km3net_offline.root")

@testset "displays" begin
    f = ROOTFile(OFFLINEFILE)
    show(devnull, f.offline[1])  # Evt
    show(devnull, f.offline[1:4])  # compact Evt
    show(devnull, f.offline[1].trks)  # Trks
    show(devnull, f.offline[1].trks[1:4])  # compact Trks
end
