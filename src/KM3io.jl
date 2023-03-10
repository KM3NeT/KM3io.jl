module KM3io

import Base: read, write
import Statistics: mean

using Printf: @printf
using Dates: DateTime, datetime2unix, unix2datetime
using StaticArrays: FieldVector
using UnROOT

export OnlineFile
export Position, UTMPosition, Location, Quaternion
export Detector, DetectorModule, PMT, Tripod, Hydrophone
export Waveform, AcousticsTriggerParameter, piezoenabled, hydrophoneenabled
export is3dshower, ismxshower, is3dmuon, isnb



# KM3NeT Dataformat definitions
for inc ∈ readdir(joinpath(@__DIR__, "definitions"), join=true)
    !endswith(inc, ".jl") && continue
    include(inc)
end


include("types.jl")

include("hardware.jl")
include("root/online.jl")
include("root/offline.jl")
include("daq.jl")
include("acoustics.jl")

include("tools.jl")

end # module
