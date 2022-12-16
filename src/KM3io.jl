module KM3io

import Base: read, write
import Statistics: mean

using Printf: @printf
using Dates: DateTime, datetime2unix, unix2datetime
using StaticArrays: FieldVector

export Position, UTMPosition, Location, Quaternion
export Detector, DetectorModule, PMT, Tripod, Hydrophone
export Waveform, AcousticsTriggerParameter, piezoenabled, hydrophoneenabled



# KM3NeT Dataformat definitions
for inc ∈ readdir(joinpath(@__DIR__, "definitions"), join=true)
    !endswith(inc, ".jl") && continue
    include(inc)
end


include("types.jl")

include("hardware.jl")
include("acoustics.jl")
include("root.jl")

include("tools.jl")

end # module
