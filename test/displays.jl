using Test

using KM3io
using KM3NeTTestData

const ONLINEFILE = datapath("online", "km3net_online.root")
const OFFLINEFILE = datapath("offline", "km3net_offline.root")

@testset "displays" begin
    f = ROOTFile(OFFLINEFILE)
    open(tempname(), "w") do io
        show(io, f.offline[1])  # Evt
        show(io, MIME"text/plain"(), f.offline[1])  # Evt
        show(io, f.offline[1:4])  # compact Evt
        show(io, f.offline[1].trks)  # Trks
        show(io, f.offline[1].trks[1:4])  # compact Trks
    end
end
