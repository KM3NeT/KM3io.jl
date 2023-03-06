module KM3io

import Base: read, write
import Statistics: mean

using DocStringExtensions

using Printf: @printf
using Dates: DateTime, datetime2unix, unix2datetime
using StaticArrays: FieldVector
using UnROOT

export OnlineFile

export Direction, Position, UTMPosition, Location, Quaternion

export Detector, DetectorModule, PMT, Tripod, Hydrophone

export Waveform, AcousticsTriggerParameter, piezoenabled, hydrophoneenabled

export is3dshower, ismxshower, is3dmuon, isnb

export Hit, TriggeredHit

export calibrate, floordist



# KM3NeT Dataformat definitions
# COV_EXCL_START
for inc ∈ readdir(joinpath(@__DIR__, "definitions"), join=true)
    !endswith(inc, ".jl") && continue
    include(inc)
end
# COV_EXCL_STOP


include("types.jl")

include("hardware.jl")
include("root/online.jl")
include("root/offline.jl")
include("daq.jl")
include("acoustics.jl")
include("calibration.jl")

include("tools.jl")

end # module
