"""

A calibrated hit of the offline dataformat. Caveat: the `position`, `direction`
and `t` fields might still be `0` due to the design philosophy of the offline
format (one class for all).

"""
struct CalibratedHit <: AbstractCalibratedHit
    dom_id::Int32
    channel_id::UInt32
    tdc::UInt32
    tot::UInt32
    trigger_mask::UInt64

    # only set when calibrated
    t::Float64  # tdc + calibration(i.e. t₀)
    pos::Position{Float64}
    dir::Direction{Float64}
end

"""

A calibrated MC hit of the offline dataformat. Caveat: the `position` and
`direction` fields might still be `0` due to the design philosophy of
the offline format (one class for all).

"""
struct CalibratedMCHit <: AbstractCalibratedMCHit
    pmt_id::Int32
    t::Float64  # MC truth
    a::Float64  # amplitude (in p.e.)
    type::Int32  # particle type or parametrisation used for hit
    origin::Int32  # track id of the track that created the hit

    # only set when calibrated
    pos::Position{Float64}
    dir::Direction{Float64}
end

"""

A container object to store fit information which uses 0-based indexing. It
implements the array interface. The entries is this vector are float values and
their position encodes the meaning of their meaning which is defined in the
[KM3NeT DataFormat](https://git.km3net.de/common/km3net-dataformat)

!!! note
    The elements of this object should always be accessed using constants
    defined in `KM3io.FITPARAMETERS`. The use of magic numbers should be
    avoided to ensure that future changes in the [KM3NeT
    DataFormat](https://git.km3net.de/common/km3net-dataformat) do not break
    existing code.

# Example

```
julia> using KM3io, KM3NeTTestData

julia> f = ROOTFile(datapath("offline", "numucc.root"))
ROOTFile{OnlineTree (0 events, 0 summaryslices), OfflineTree (10 events)}

julia> reco = bestjppmuon(f.offline[1])
Trk (Reconstructed track)
  id: 1
  pos: Position{Float64}(-647.396, -138.621, 319.288)
  dir: Direction{Float64}(0.939, 0.269, 0.213)
  t: 8.849343007963674e7
  E: 117.28604237509933
  len: 0.0
  lik: 92.7921433955364
  rec_type: 4000
  rec_stages: Int32[1, 2, 3, 4, 5]
  fitinf: FitInformation([0.0020367251782607574, 0.0014177681261476852, -92.7921433955364, 107.0, 1141.8713789917795, 264.38698486751207, 0.3629813537326686, 11.0, 5.265362302261376, 13.45233763002935, 671.9039327646219, 0.0, 0.0, 2543.769772201125, -312.0874580760447, 31061.0, 107.0])

julia> reco.fitinf[KM3io.FITPARAMETERS.JGANDALF_CHI2]
-92.7921433955364
```
"""
struct FitInformation
    values::Vector{Float64}
end
==(a::T, b::T) where T<:FitInformation = a.values == b.values
Base.getindex(fitinf::FitInformation, idx) = fitinf.values[idx + 1]
Base.length(fitinf::FitInformation) = length(fitinf.values)
Base.size(fitinf::FitInformation) = (length(fitinf),)
Base.firstindex(::FitInformation) = 0
Base.lastindex(fitinf::FitInformation) = length(fitinf) - 1
Base.eltype(::FitInformation) = Float64
function Base.iterate(fitinf::FitInformation, state=0)
    state > length(fitinf)-1 ? nothing : (fitinf[state], state+1)
end

"""
Represents a reconstructed "track", which can be e.g. a muon track but also a shower.
"""
struct Trk
    id::Int
    pos::Position{Float64}
    dir::Direction{Float64}
    t::Float64
    E::Float64  # [GeV]
    len::Float64
    lik::Float64
    rec_type::Int32
    rec_stages::Vector{Int32}
    fitinf::FitInformation
end
function ==(a::T, b::T) where T<:Trk
    typeof(a) === typeof(b) || return false
    for name in fieldnames(T)
        getfield(a, name) == getfield(b, name) || return false
    end
    return true
end

"""
A simulated (Monte Carlo, hence "MC") track (or shower).
"""
struct MCTrk
    id::Int
    pos::Position{Float64}
    dir::Direction{Float64}
    t::Float64
    E::Float64  # [GeV]
    len::Float64
    type::Int32  # PDG id
    status::Int32  # see KM3io.TRKMEMBERS
    mother_id::Int32  # MC id of the parent particle
    counter::Int32  # used by Corsika7 MC generation to store interaction counters
end

"""

An offline event.

"""
struct Evt
    id::Int64  # offline event identifier
    det_id::Int64
    mc_id::Int64

    run_id::Int64
    mc_run_id::Int64

    frame_index::Int64
    trigger_mask::UInt64
    trigger_counter::UInt64
    overlays::UInt64
    t::UTCTime

    # TODO: unclear how UUID is set
    # header_uuid::UUID

    hits::Vector{CalibratedHit}
    trks::Vector{Trk}

    # MC related fields
    w::Vector{Float64}
    w2list::Vector{Float64}  # (see e.g. <a href="https://simulation.pages.km3net.de/taglist/taglist.pdf">Tag list</a> or km3net-dataformat/definitions)
    w3list::Vector{Float64}  # atmospheric flux information

    mc_event_time::UTCTime
    mc_t::Float64
    mc_hits::Vector{CalibratedMCHit}
    mc_trks::Vector{MCTrk}

    # comment::AbstractString
    index::Int64
    flags::Int64
    usr::Dict{String, Float64}
end
function ==(a::Evt, b::Evt)
    typeof(a) === typeof(b) || return false
    for name in fieldnames(Evt)
        getfield(a, name) == getfield(b, name) || return false
    end
    return true
end

struct MCHeader
    _raw::Dict{String, String}
end
function Base.show(io::IO, h::MCHeader)
    println(io, "MCHeader")
    for prop ∈ sort(propertynames(h))
        println(io, "  $(prop) => $(getproperty(h, prop))")
    end
end
Base.propertynames(h::MCHeader) = Symbol.(keys(h._raw))
function Base.getproperty(h::MCHeader, s::Symbol)
    s == :_raw && return getfield(h, s)
    if s ∈ propertynames(h)
        values = Any[tonumifpossible(v) for v ∈ split(strip(h._raw[String(s)]))]
        if s ∈ keys(MCHEADERDEF)
            fieldnames = collect(MCHEADERDEF[s])
            # fill up with missing if not all fields are provided
            while length(values) < length(fieldnames)
                push!(values, missing)
            end
            # fill up with enumerated fieldnames if more values are provided
            # using the same indexing as in km3io
            i = length(fieldnames)
            while length(fieldnames) < length(values)
                push!(fieldnames, Symbol("field_$(i)"))
                i += 1
            end
            return NamedTuple(zip(fieldnames, values))
        end
        length(values) == 1 && return values[1]
        return values
    end
    error("no MC header entry found for '$(String(s))'")
end


struct OfflineTree{T}
    _fobj::UnROOT.ROOTFile
    header::Union{MCHeader, Missing}
    _frame_index_trigger_counter_lookup_map::Dict{Tuple{Int, Int}, Int}
    _t::T  # carry the type to ensure type-safety

    function OfflineTree(fobj::UnROOT.ROOTFile)
        tpath = ROOT.TTREE_OFFLINE_EVENT
        bpath = ROOT.TBRANCH_OFFLINE_EVENT

        aaobject_keys = getproperty.(UnROOT.children(fobj["E/Evt/AAObject"]), :fName)
        has_usr_fields = "usr" in aaobject_keys && "usr_names" in aaobject_keys

        branch_paths =[
            bpath * "/id",
            bpath * "/det_id",
            bpath * "/mc_id",
            bpath * "/run_id",
            bpath * "/mc_run_id",
            bpath * "/frame_index",
            bpath * "/trigger_mask",
            bpath * "/trigger_counter",
            bpath * "/overlays",
            Regex(bpath * "/t/t.f(Sec|NanoSec)\$") => s"t_\1",
            # bpath * "/header_uuid",
            Regex(bpath * "/hits/hits.(id|dom_id|channel_id|tdc|tot|trig|t)\$") => s"hits_\1",
            Regex(bpath * "/hits/hits.(pos|dir).([xyz])\$") => s"hits_\1_\2",
            Regex(bpath * "/trks/trks.(id|t|E|len|lik|rec_type|rec_stages|fitinf)\$") => s"trks_\1",
            Regex(bpath * "/trks/trks.(pos|dir).([xyz])\$") => s"trks_\1_\2",
            bpath * "/w",
            bpath * "/w2list",
            bpath * "/w3list",
            # mc_event_time was introduced in 2020-11-05
            # https://git.km3net.de/common/km3net-dataformat/-/commit/a44aed0fbc930b65bb94193c718250bb000d617b
            Regex(bpath * "/mc_event_time/mc_event_time.f(Sec|NanoSec)\$") => s"mc_event_time_\1",
            bpath * "/mc_t",  # time where the simulated event was inserted in the timeslice
            Regex(bpath * "/mc_hits/mc_hits.(id|pmt_id|t|a|pure_t|pure_a|type|origin)\$") => s"mc_hits_\1",
            Regex(bpath * "/mc_hits/mc_hits.(pos|dir).([xyz])\$") => s"mc_hits_\1_\2",
            Regex(bpath * "/mc_trks/mc_trks.(id|t|E|len|type|status|mother_id|counter)\$") => s"mc_trks_\1",
            Regex(bpath * "/mc_trks/mc_trks.(pos|dir).([xyz])\$") => s"mc_trks_\1_\2",
            bpath * "/index",
            bpath * "/flags",
        ]

        if has_usr_fields
            push!(branch_paths, bpath * "/AAObject/usr")
            push!(branch_paths, bpath * "/AAObject/usr_names")
        end

        t = UnROOT.LazyTree(fobj, tpath, branch_paths)

        header = "Head" ∈ keys(fobj) ? MCHeader(fobj["Head"]) : missing

        new{typeof(t)}(fobj, header, Dict{Tuple{Int, Int}, Int}(), t)
    end
end
OfflineTree(filename::AbstractString) = OfflineTree(UnROOT.ROOTFile(filename))

Base.close(f::OfflineTree) = close(f._fobj)
Base.length(f::OfflineTree) = length(f._t.Evt_id)
Base.size(f::OfflineTree) = (length(f),)
Base.firstindex(f::OfflineTree) = 1
Base.lastindex(f::OfflineTree) = length(f)
Base.eltype(::OfflineTree) = Evt
function Base.iterate(f::OfflineTree, state=1)
    state > length(f) ? nothing : (f[state], state+1)
end
function Base.show(io::IO, f::OfflineTree)
    print(io, "OfflineTree ($(length(f)) events)")
end
"""
    function Base.getindex(f::OfflineTree, b::AbstractString, ::Colon)

Shortcut to access only a specific branch of the ROOT tree.
Requires knowledge of the ROOT branch structure.

# Example
```
julia> f = ROOTFile(datapath("offline", "numucc.root"))
ROOTFile{OnlineTree (0 events, 0 summaryslices), OfflineTree (10 events)}

julia> f.offline["t/t.fSec", :]
10-element Vector{Int32}:
  3
  7
  8
 10
 13
 26
 27
 43
 51
 52

julia> f.offline["hits/hits.id", :]
10-element ArraysOfArrays.VectorOfVectors{Int32, Vector{Int32}, Vector{Int32}, Vector{Tuple{}}}:
 Int32[0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
 Int32[0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
 Int32[0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
 Int32[0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
 Int32[0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
 Int32[0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
 Int32[0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
 Int32[0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
 Int32[0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
 Int32[0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
```

"""
function Base.getindex(f::OfflineTree, b::AbstractString, ::Colon)
    tpath = ROOT.TTREE_OFFLINE_EVENT
    bpath = ROOT.TBRANCH_OFFLINE_EVENT
    UnROOT.array(f._fobj, tpath * "/" * bpath * "/$(b)")
end
Base.getindex(f::OfflineTree, r::UnitRange) = [f[idx] for idx ∈ r]
Base.getindex(f::OfflineTree, mask::BitArray) = [f[idx] for (idx, selected) ∈ enumerate(mask) if selected]
function Base.getindex(f::OfflineTree, idx::Integer)::Evt
    idx > length(f) && throw(BoundsError(f, idx))
    e = f._t[idx]  # the event as NamedTuple: struct of arrays

    skip_mc_event_time = !hasproperty(e, :mc_event_time_Sec)
    has_usr_fields = hasproperty(e, :Evt_AAObject_usr)

    if has_usr_fields
        usr_dct = Dict(e.Evt_AAObject_usr_names .=> e.Evt_AAObject_usr)
    else
        usr_dct = Dict{String, Float64}()
    end

    n = length(e.mc_hits_id)
    mc_hits = sizehint!(Vector{CalibratedMCHit}(), n)
    for i ∈ 1:n
        push!(mc_hits,
              CalibratedMCHit(
                  e.mc_hits_pmt_id[i],
                  e.mc_hits_t[i],
                  e.mc_hits_a[i],
                  e.mc_hits_type[i],
                  e.mc_hits_origin[i],
                  Position(e.mc_hits_pos_x[i], e.mc_hits_pos_y[i], e.mc_hits_pos_z[i]),
                  Direction(e.mc_hits_dir_x[i], e.mc_hits_dir_y[i], e.mc_hits_dir_z[i])
              )
        )
    end

    n = length(e.hits_id)
    hits = sizehint!(Vector{CalibratedHit}(), n)
    for i ∈ 1:n
        push!(hits,
              CalibratedHit(
                  e.hits_dom_id[i],
                  e.hits_channel_id[i],
                  e.hits_tdc[i],
                  e.hits_tot[i],
                  e.hits_trig[i],
                  e.hits_t[i],
                  Position(e.hits_pos_x[i], e.hits_pos_y[i], e.hits_pos_z[i]),
                  Direction(e.hits_dir_x[i], e.hits_dir_y[i], e.hits_dir_z[i])
              )
        )
    end

    n = length(e.mc_trks_id)
    mc_trks = sizehint!(Vector{MCTrk}(), n)
    # legacy format support
    skip_mc_trks_status = !hasproperty(e, :mc_trks_status)
    skip_mc_trks_mother_id = !hasproperty(e, :mc_trks_mother_id)
    skip_mc_trks_counter = !hasproperty(e, :mc_trks_counter)
    for i ∈ 1:n
        push!(mc_trks,
            MCTrk(
                e.mc_trks_id[i],
                Position(e.mc_trks_pos_x[i], e.mc_trks_pos_y[i], e.mc_trks_pos_z[i]),
                Direction(e.mc_trks_dir_x[i], e.mc_trks_dir_y[i], e.mc_trks_dir_z[i]),
                e.mc_trks_t[i],
                e.mc_trks_E[i],
                e.mc_trks_len[i],
                e.mc_trks_type[i],
                skip_mc_trks_status ? 0 : e.mc_trks_status[i],
                skip_mc_trks_mother_id ? 0 : e.mc_trks_mother_id[i],
                skip_mc_trks_counter ? 0 : e.mc_trks_counter[i],
            )
        )
    end

    n = length(e.trks_id)
    trks = sizehint!(Vector{Trk}(), n)
    for i ∈ 1:n
        push!(trks,
            Trk(
                e.trks_id[i],
                Position(e.trks_pos_x[i], e.trks_pos_y[i], e.trks_pos_z[i]),
                Direction(e.trks_dir_x[i], e.trks_dir_y[i], e.trks_dir_z[i]),
                e.trks_t[i],
                e.trks_E[i],
                e.trks_len[i],
                e.trks_lik[i],
                e.trks_rec_type[i],
                e.trks_rec_stages[i],
                FitInformation(e.trks_fitinf[i]),
            )
        )
    end

    Evt(
        e.Evt_id,
        e.Evt_det_id,
        e.Evt_mc_id,
        e.Evt_run_id,
        e.Evt_mc_run_id,
        e.Evt_frame_index,
        e.Evt_trigger_mask,
        e.Evt_trigger_counter,
        e.Evt_overlays,
        UTCTime(e.t_Sec, e.t_NanoSec),
        hits,
        trks,
        e.Evt_w,
        e.Evt_w2list,
        e.Evt_w3list,
        skip_mc_event_time ? UTCTime(0.0, 0.0) : UTCTime(e.mc_event_time_Sec, e.mc_event_time_NanoSec),
        e.Evt_mc_t,
        mc_hits,
        mc_trks,
        e.Evt_index,
        e.Evt_flags,
        usr_dct
    )
end


