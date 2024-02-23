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

export ROOTFile
export H5File, H5CompoundDataset, create_dataset, addmeta

export Direction, Position, UTMPosition, Location, Quaternion, Track, AbstractCalibratedHit
export Detector, DetectorModule, PMT, Tripod, Hydrophone, StringMechanics, StringMechanicsParameters,
       center, isbasemodule, isopticalmodule, getmodule, modules, getpmt, getpmts, haslocation

# Acoustics
export Waveform, AcousticSignal, AcousticsTriggerParameter, piezoenabled, hydrophoneenabled

# Online dataformat
export DAQEvent, EventHeader, SnapshotHit, UTCTime, UTCExtended, Summaryslice,
       SummarysliceHeader, SummaryFrame,
       pmtrate, pmtrates, hrvstatus, tdcstatus, wrstatus, fifostatus, hasudptrailer,
       count_active_channels, count_fifostatus, count_hrvstatus, status,
       maximal_udp_sequence_number, number_of_udp_packets_received, CLBCommonHeader, InfoWord

# Offline dataformat
export Evt, TriggeredHit, Trk, CalibratedHit, XCalibratedHit, MCTrk, CalibratedMCHit, CalibratedSnapshotHit,
       CalibratedTriggeredHit

export K40Rates

export calibrate, calibratetime, floordist, slew, combine

export besttrack, bestjppmuon, bestjppshower, bestaashower,
       RecStageRange, hashistory, hasjppmuonprefit, hasjppmuonsimplex, hasjppmuongandalf,
       hasjppmuonenergy, hasjppmuonstart, hasjppmuonfit, hasshowerprefit, hasshowerpositionfit,
       hasshowercompletefit, hasshowerfit, hasaashowerfit, hasreconstructedjppmuon,
       hasreconstructedjppshower, hasreconstructedaashower

export is3dshower, ismxshower, is3dmuon, isnb, triggered
export most_frequent, categorize, nthbitset

export cherenkov, CherenkovPhoton, azimuth, zenith, theta, phi

export MCEventMatcher

export CHClient, CHTag, subscribe, @ip_str

export distance

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
include("csk.jl")

include("tools/general.jl")
include("tools/daq.jl")
include("tools/trigger.jl")
include("tools/reconstruction.jl")
include("tools/math.jl")
include("tools/helpers.jl")

include("physics.jl")

end # module
