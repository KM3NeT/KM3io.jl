module KM3io

import Base: read, write, ==
import Statistics: mean
using Dates
using LinearAlgebra
using Printf: @printf
using Dates: DateTime, datetime2unix, unix2datetime
using Sockets
using UUIDs
using TOML
using JSON
using ProgressMeter

if !isdefined(Base, :get_extension)
    using Requires
end

const version = let
    if VERSION < v"1.9"
        VersionNumber(TOML.parsefile(joinpath(pkgdir(KM3io), "Project.toml"))["version"])
    else
        pkgversion(KM3io)
    end
end

using DocStringExtensions
using StaticArrays: FieldVector, @SArray, SVector, Size
import StaticArrays: similar_type
import UnROOT

using HDF5
using Corpuscles


include("exports.jl")


@template (FUNCTIONS, METHODS, MACROS) =
    """
    $(TYPEDSIGNATURES)
    $(DOCSTRING)
    """

@template TYPES = """
    $(TYPEDEF)

    $(DOCSTRING)

    # Fields
    $(TYPEDFIELDS)
    """


# KM3NeT Dataformat definitions
# COV_EXCL_START
for inc ∈ readdir(joinpath(@__DIR__, "definitions"), join=true)
    !endswith(inc, ".jl") && continue
    include(inc)
end

include("constants.jl")
# COV_EXCL_STOP

include("types.jl")

include("hardware.jl")
include("root/online.jl")
include("root/offline.jl")
include("root/oscillations.jl")
include("root/root.jl")
include("root/calibration.jl")
include("hdf5/hdf5.jl")
include("daq.jl")
include("acoustics.jl")
include("calibration.jl")
include("controlhost.jl")
include("json.jl")

include("tools/general.jl")
include("tools/daq.jl")
include("tools/trigger.jl")
include("tools/reconstruction.jl")
include("tools/math.jl")
include("tools/coords.jl")
include("tools/helpers.jl")

include("physics.jl")

include("displays.jl")


function __init__()
    @static if !isdefined(Base, :get_extension)
        @require KM3DB="a9013879-bb44-4449-9e5b-40f9ac008ab0" include("../ext/KM3ioKM3DBExt.jl")
    end
end

end # module
