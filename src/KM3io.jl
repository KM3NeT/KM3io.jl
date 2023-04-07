module KM3io

import Base: read, write
import Statistics: mean
using LinearAlgebra
using Printf: @printf
using Dates: DateTime, datetime2unix, unix2datetime
using UUIDs

using DocStringExtensions
using StaticArrays: FieldVector
using UnROOT

export OnlineFile, OfflineFile

export Direction, Position, UTMPosition, Location, Quaternion
export Detector, DetectorModule, PMT, Tripod, Hydrophone
export Waveform, AcousticSignal, AcousticsTriggerParameter, piezoenabled, hydrophoneenabled
export Hit, TriggeredHit

export calibrate, floordist, slew
export is3dshower, ismxshower, is3dmuon, isnb
export most_frequent, categorize, nthbitset

@template (FUNCTIONS, METHODS, MACROS) =
    """
    $(TYPEDSIGNATURES)
    $(DOCSTRING)
    """

@template TYPES = """
    $(TYPEDEF)

    # Fields
    $(TYPEDFIELDS)

    $(DOCSTRING)
    """


# KM3NeT Dataformat definitions
# COV_EXCL_START
for inc ∈ readdir(joinpath(@__DIR__, "definitions"), join=true)
    !endswith(inc, ".jl") && continue
    include(inc)
end
# COV_EXCL_STOP


include("constants.jl")

include("types.jl")

include("hardware.jl")
include("root/online.jl")
include("root/offline.jl")
include("daq.jl")
include("acoustics.jl")
include("calibration.jl")

include("tools.jl")
include("physics.jl")

end # module
