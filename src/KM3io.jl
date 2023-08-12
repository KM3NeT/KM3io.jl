module KM3io

import Base: read, write
import Statistics: mean
using LinearAlgebra
using Printf: @printf
using Dates: DateTime, datetime2unix, unix2datetime
using Sockets
using UUIDs
import Pkg

const version = VersionNumber(Pkg.TOML.parsefile(joinpath(pkgdir(KM3io), "Project.toml"))["version"])

using DocStringExtensions
using StaticArrays: FieldVector, @SArray, SVector
import UnROOT

using HDF5

export ROOTFile
export H5File, H5CompoundDataset, create_dataset

export Direction, Position, UTMPosition, Location, Quaternion, Track, AbstractCalibratedHit
export Detector, DetectorModule, PMT, Tripod, Hydrophone, center, isbasemodule

# Acoustics
export Waveform, AcousticSignal, AcousticsTriggerParameter, piezoenabled, hydrophoneenabled

# Online dataformat
export DAQEvent, pmtrate, pmtrates, hrvstatus, tdcstatus, wrstatus, fifostatus
# Offline dataformat
export Evt, Hit, TriggeredHit, Trk, CalibratedHit, XCalibratedHit, MCTrk, CalibratedMCHit

export K40Rates

export calibrate, floordist, slew

export besttrack, bestjppmuon, bestjppshower, bestaashower,
       RecStageRange, hashistory, hasjppmuonprefit, hasjppmuonsimplex, hasjppmuongandalf,
       hasjppmuonenergy, hasjppmuonstart, hasjppmuonfit, hasshowerprefit, hasshowerpositionfit,
       hasshowercompletefit, hasshowerfit, hasaashowerfit, hasreconstructedjppmuon,
       hasreconstructedjppshower, hasreconstructedaashower

export is3dshower, ismxshower, is3dmuon, isnb, triggered
export most_frequent, categorize, nthbitset

export cherenkov, CherenkovPhoton, azimuth, zenith, theta, phi

export CHClient, CHTag, subscribe, @ip_str

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

include("physics.jl")

if get_package_version("HDF5") < v"0.16.15"
    # backport of the fix in https://github.com/JuliaIO/HDF5.jl/pull/1069
    HDF5.datatype(::Type{T}) where {T} = HDF5.Datatype(HDF5.hdf5_type_id(T), isstructtype(T))
end

end # module
