module KM3io

import Base: read, write
import Statistics: mean
using LinearAlgebra
using Printf: @printf
using Dates: DateTime, datetime2unix, unix2datetime
using Sockets
using UUIDs

using DocStringExtensions
using StaticArrays: FieldVector, SVector
import UnROOT

using HDF5
# TODO: this will be fixed when https://github.com/JuliaIO/HDF5.jl/pull/1069
# is merged. HDF5 dependency should then be set to ^0.16.14 and the following
# line removed
HDF5.datatype(::Type{T}) where {T} = HDF5.Datatype(HDF5.hdf5_type_id(T), isstructtype(T))

export ROOTFile
export H5File, H5CompoundDataset, create_dataset

export Direction, Position, UTMPosition, Location, Quaternion, Track, AbstractCalibratedHit
export Detector, DetectorModule, PMT, Tripod, Hydrophone, center, isbasemodule

# Acoustics
export Waveform, AcousticSignal, AcousticsTriggerParameter, piezoenabled, hydrophoneenabled

# Online dataformat
export DAQEvent
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

export cherenkov, CherenkovPhoton

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
include("tools/trigger.jl")
include("tools/reconstruction.jl")

include("physics.jl")

end # module
