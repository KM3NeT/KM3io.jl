module KM3io

import Base: read, write
import Statistics: mean
using LinearAlgebra
using Printf: @printf
using Dates: DateTime, datetime2unix, unix2datetime
using Sockets
using UUIDs
using TOML

const version = let
    if VERSION < v"1.9"
        VersionNumber(TOML.parsefile(joinpath(pkgdir(KM3io), "Project.toml"))["version"])
    else
        pkgversion(KM3io)
    end
end

using DocStringExtensions
using StaticArrays: FieldVector, @SArray, SVector
import UnROOT

using HDF5


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
include("root/root.jl")
include("hdf5/hdf5.jl")
include("daq.jl")
include("acoustics.jl")
include("calibration.jl")
include("controlhost.jl")

include("tools/general.jl")
include("tools/daq.jl")
include("tools/trigger.jl")
include("tools/reconstruction.jl")
include("tools/math.jl")
include("tools/helpers.jl")

include("physics.jl")

end # module
