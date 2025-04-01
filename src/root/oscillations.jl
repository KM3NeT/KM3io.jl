"""
`OscillationsData` is an abstract type representing the data in an oscillation open data file.

"""
abstract type OscillationsData end

"""
`_check_version` is a function to check for the version of the file if it is supported.

"""

function _check_version(filename::String)
    match_result = match(r"_v(\d+\.\d+)", filename)
    if match_result !== nothing
        version = match_result.captures[1]
        if version == "0.5"
            return true
        else
            error("Only version supported now is v 0.5 . Not supported version: $version")
        end
    else
        error("Version not found in filename: $filename")
    end
end

"""

`OSCFile` is a structure representing an oscillation open data file. Depending on the trees inside the root file it will have different fields (neutrino, muons, data).

"""
struct OSCFile
    _fobj::Union{UnROOT.ROOTFile,Dict}
    rawroot::Union{UnROOT.ROOTFile,Nothing}
    osc_opendata_nu::Union{OscillationsData,Nothing}
    osc_opendata_data::Union{OscillationsData,Nothing}
    osc_opendata_muons::Union{OscillationsData,Nothing}

    function OSCFile(filename::AbstractString)
        _check_version(filename)
        if endswith(filename, ".root")
            fobj = UnROOT.ROOTFile(filename)
            osc_opendata_nu = ROOT.TTREE_OSC_OPENDATA_NU ∈ keys(fobj) ? OscOpenDataTree(fobj, ROOT.TTREE_OSC_OPENDATA_NU) : nothing
            osc_opendata_data = ROOT.TTREE_OSC_OPENDATA_DATA ∈ keys(fobj) ? OscOpenDataTree(fobj, ROOT.TTREE_OSC_OPENDATA_DATA) : nothing
            osc_opendata_muons = ROOT.TTREE_OSC_OPENDATA_MUONS ∈ keys(fobj) ? OscOpenDataTree(fobj, ROOT.TTREE_OSC_OPENDATA_MUONS) : nothing
            return new(fobj, fobj, osc_opendata_nu, osc_opendata_data, osc_opendata_muons)
        end
    end
end
Base.close(f::OSCFile) = close(f._fobj)
function Base.show(io::IO, f::OSCFile)
    if isa(f._fobj, UnROOT.ROOTFile)
        s = String[]
        !isnothing(f.osc_opendata_nu) && push!(s, "$(f.osc_opendata_nu)")
        !isnothing(f.osc_opendata_data) && push!(s, "$(f.osc_opendata_data)")
        !isnothing(f.osc_opendata_muons) && push!(s, "$(f.osc_opendata_muons)")
        info = join(s, ", ")
        print(io, "OSCFile{$info}")
    else
        print(io, "Empty OSCFile")
    end

end

const NUE_PDGID = Particle("nu(e)0").pdgid.value
const ANUE_PDGID = Particle("~nu(e)0").pdgid.value
const NUMU_PDGID = Particle("nu(mu)0").pdgid.value
const ANUMU_PDGID = Particle("~nu(mu)0").pdgid.value
const NUTAU_PDGID = Particle("nu(tau)0").pdgid.value
const ANUTAU_PDGID = Particle("~nu(tau)0").pdgid.value

"""

A `ResponseMatrixBin` is an abstract type representing a bin in a response matrix.

"""
abstract type ResponseMatrixBin end

"""

A concrete type representing a response matrix bin for neutrino events.

"""
struct ResponseMatrixBinNeutrinos <: ResponseMatrixBin
    E_reco_bin::Int64
    Ct_reco_bin::Int64
    E_reco_bin_center::Float64
    Ct_reco_bin_center::Float64
    E_true_bin::Int64
    Ct_true_bin::Int64
    E_true_bin_center::Float64
    Ct_true_bin_center::Float64
    Pdg::Int16
    IsCC::Int16
    AnaClass::Int16
    W::Float64
    WE::Float64
end

"""

A concrete type representing a response matrix bin for muon events. There is no true quantities for muon events.

"""
struct ResponseMatrixBinMuons <: ResponseMatrixBin
    E_reco_bin::Int64
    Ct_reco_bin::Int64
    E_reco_bin_center::Float64
    Ct_reco_bin_center::Float64
    AnaClass::Int16
    W::Float64
    WE::Float64
end

"""

A concrete type representing a response matrix bin for data events. There is no true quantities for data events.

"""
struct ResponseMatrixBinData <: ResponseMatrixBin
    E_reco_bin::Int64
    Ct_reco_bin::Int64
    E_reco_bin_center::Float64
    Ct_reco_bin_center::Float64
    AnaClass::Int16
    W::Float64
end


"""

Function to get the PDG ID for a given neutrino flavor and neutrino/antineutrino flag.

"""
function _getpdgnumber(flav::Integer, isNB::Integer)
    flav == 0 && isNB == 0 && return NUE_PDGID # nu(e)0
    flav == 0 && isNB == 1 && return ANUE_PDGID # ~nu(e)0
    flav == 1 && isNB == 0 && return NUMU_PDGID # nu(mu)0
    flav == 1 && isNB == 1 && return ANUMU_PDGID # ~nu(mu)0
    flav == 2 && isNB == 0 && return NUTAU_PDGID # nu(tau)0
    flav == 2 && isNB == 1 && return ANUTAU_PDGID # ~nu(tau)0

    error("Invalid flavor: $flav($isNB)")
end

"""

Function to get the name of the analysis class based on its identifier.

"""
function _getanaclassname(fClass::Integer)
    fClass == 1 && return "HighPurityTracks"
    fClass == 2 && return "Showers"
    fClass == 3 && return "LowPurityTracks"
    error("Invalid class: $fClass)")
end

"""

`OscOpenDataTree` is a structure representing an oscillation open data tree, it will be represented as response functions.

"""
struct OscOpenDataTree{T} <: OscillationsData
    _fobj::UnROOT.ROOTFile
    #header::Union{MCHeader, Missing} # no header for now, subject to change
    _bin_lookup_map::Dict{Tuple{Int,Int,Int},Int} # Not implemented for now
    _t::T  # carry the type to ensure type-safety
    tpath::String

    function OscOpenDataTree(fobj::UnROOT.ROOTFile, tpath::String)
        if tpath == ROOT.TTREE_OSC_OPENDATA_NU
            branch_paths = [
                "E_reco_bin",
                "Ct_reco_bin",
                "E_reco_bin_center",
                "Ct_reco_bin_center",
                "Pdg",
                "IsCC",
                "E_true_bin",
                "Ct_true_bin",
                "E_true_bin_center",
                "Ct_true_bin_center",
                "W",
                "WE",
                "AnaClass",
            ]

        elseif tpath == ROOT.TTREE_OSC_OPENDATA_DATA
            branch_paths = [
                "E_reco_bin",
                "Ct_reco_bin",
                "E_reco_bin_center",
                "Ct_reco_bin_center",
                "W",
                "AnaClass",
            ]
        elseif tpath == ROOT.TTREE_OSC_OPENDATA_MUONS 
            branch_paths = [
                "E_reco_bin",
                "Ct_reco_bin",
                "E_reco_bin_center",
                "Ct_reco_bin_center",
                "W",
                "WE",
                "AnaClass",
            ]
        end


        t = UnROOT.LazyTree(fobj, tpath, branch_paths)

        new{typeof(t)}(fobj, Dict{Tuple{Int,Int,Int},Int}(), t, tpath)
    end
end

"""

Construct an `OscOpenDataTree` from a ROOT file and a tree path.

"""
OscOpenDataTree(filename::AbstractString, tpath::String) = OscOpenDataTree(UnROOT.ROOTFile(filename), tpath)

Base.close(f::OscOpenDataTree) = close(f._fobj)
Base.length(f::OscOpenDataTree) = length(f._t)
Base.firstindex(f::OscOpenDataTree) = 1
Base.lastindex(f::OscOpenDataTree) = length(f)
Base.eltype(::OscOpenDataTree) = ResponseMatrixBin
function Base.iterate(f::OscOpenDataTree, state=1)
    state > length(f) ? nothing : (f[state], state + 1)
end
function Base.show(io::IO, f::OscOpenDataTree)
    data_name = f.tpath == ROOT.TTREE_OSC_OPENDATA_NU ? "Neutrinos" :
                f.tpath == ROOT.TTREE_OSC_OPENDATA_DATA ? "Data" :
                f.tpath == ROOT.TTREE_OSC_OPENDATA_MUONS ? "Muons" : "Unknown"
    print(io, "OscOpenDataTree of $(data_name) ($(length(f)) events)")
end

Base.getindex(f::OscOpenDataTree, r::UnitRange) = [f[idx] for idx ∈ r]
Base.getindex(f::OscOpenDataTree, mask::BitArray) = [f[idx] for (idx, selected) ∈ enumerate(mask) if selected]
function Base.getindex(f::OscOpenDataTree, idx::Integer)
    if idx > length(f)
        throw(BoundsError(f, idx))
    end
    idx > length(f) && throw(BoundsError(f, idx))
    e = f._t[idx]  # the event as NamedTuple: struct of arrays

    if f.tpath == ROOT.TTREE_OSC_OPENDATA_NU
        ResponseMatrixBinNeutrinos(
            e.E_reco_bin,
            e.Ct_reco_bin,
            e.E_reco_bin_center,
            e.Ct_reco_bin_center,
            e.E_true_bin,
            e.Ct_true_bin,
            e.E_true_bin_center,
            e.Ct_true_bin_center,
            e.Pdg,
            e.IsCC,
            e.AnaClass,
            e.W,
            e.WE)
    elseif f.tpath == ROOT.TTREE_OSC_OPENDATA_MUONS
        ResponseMatrixBinMuons(
            e.E_reco_bin,
            e.Ct_reco_bin,
            e.E_reco_bin_center,
            e.Ct_reco_bin_center,
            e.AnaClass,
            e.W,
            e.WE)
    elseif f.tpath == ROOT.TTREE_OSC_OPENDATA_DATA
        ResponseMatrixBinData(
            e.E_reco_bin,
            e.Ct_reco_bin,
            e.E_reco_bin_center,
            e.Ct_reco_bin_center,
            e.AnaClass,
            e.W)
    end

end

