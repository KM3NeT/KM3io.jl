# DST tree / directory names. These are not part of the upstream
# km3net-dataformat definitions yet; once they are, move them to
# src/definitions/root.jl.
const TTREE_DST_SUMMARY      = "T"            # DST summary tree
const TTREE_DST_HEADER       = "headerTree"   # per-source-file DST header
const TDIRECTORY_DST_HISTORY = "dst_history"  # DST provenance directory
const TDIRECTORY_DST_HEADDIR = "HeadDir"      # per-key TNamed header directory

"""
Description registry of top-level branch names commonly found in KM3NeT
DST `T` trees. Maps the branch name (as stored in the ROOT file) to a
short human-readable description.

This is a *documentation aid*, not an enforcement mechanism. A `DSTTree`
exposes whatever branches the file actually contains; entries here just
let users look up the meaning of well-known names. Most descriptions
mirror the upstream documentation at
https://common.pages.km3net.de/aanet/dstpage.html .

Use [`describe_dst_branch`](@ref) to query, and append to this dict to
register new names locally.
"""
const DST_BRANCHES = Dict{String, String}(
    "sum_mc_evt"        => "Per-event MC truth summary (MC_evts_summary): weight, weight_noOsc, livetime_DAQ [s], livetime_sim [s], n_gen, E_min_gen, E_max_gen [GeV], MC_run.",
    "sum_mc_trks"       => "MC tracks summary (MC_trks_summary): ntrks, Etot, Emax, Evis [GeV], plus the highest-energy MC muon as a flattened Trk (tmuon_*).",
    "sum_mc_hits"       => "MC hits summary (MC_hits_summary or hits_summary): hit count, total amplitude [pe], time bounds [ns], and (for hits_summary) DOM/line counts.",
    "sum_mc_nu"         => "MC neutrino interaction summary (nu_summary): Bjorken bx, by; ichan, cc flag; atmospheric flux for numu, nue and oscillated total atm_flux [GeV^-1 s^-1 sr^-1 m^-2]; oscillation probabilities posc_from_numu, posc_from_nue; path_length [km] according to the PREM model.",
    "sum_hits"          => "All-hits summary (hits_summary): nhits, atot, tmin, tmax, ndoms, nlines.",
    "sum_trig_hits"     => "Triggered-hits summary (hits_summary).",
    "sum_casc"          => "Cascade reconstruction summary (cascade_summary): aashower hit/total counts in time windows, inertia tensor metrics. Observed in v6 productions; not documented upstream.",
    "crkv_hits"         => "Expected Cherenkov hits binned by distance from vertex (crkv_hits / Cherenkov_hits): nhits, per-shell counts (20m, 50m, 100m, 200m), sumtot, closest, furthest [m].",
    "sum_jppmuon"       => "Jpp muon track reconstruction summary (rec_trks_summary): ntrks, cos-zenith bounds, n_within_1deg, up/down counts and likelihoods.",
    "sum_jpptrack"      => "Jpp track reconstruction summary (rec_trks_summary).",
    "sum_jgandalf"      => "JGandalf reconstruction summary (rec_trks_summary).",
    "sum_aashower"      => "AAShower reconstruction summary (rec_trks_summary).",
    "sum_jshower"       => "Jpp shower reconstruction summary (rec_trks_summary).",
    "sum_jppshower"     => "Jpp shower fit quality metrics (jppshower_summary): prefit-postfit distance and dt, ratio_prefit_fits_near_best, mean_tres_selected_hits, n_selected_hits, n_prefit, n_near_prefit.",
    "sum_dusjshower"    => "Dusj shower reconstruction summary (rec_trks_summary).",
    "coords"            => "Celestial coordinates in the J2000 system (Celestial_coordinates): mjd, plus right-ascension and declination [rad] for the MC neutrino, the track fit and the shower fit.",
    "feat_Neutrino2020" => "ORCA Neutrino 2020 reconstruction features (ORCA_Neutrino2020): Cherenkov-condition trigger statistics (cherCond_*), gandalf charges and hit counts, Q-based metrics, closest-approach geometry, minimum-DOM-Z, mean-Z hit positions.",
    "bdt"               => "BDT score(s); typically a small array per event.",
    "bdt_trk"           => "BDT score(s) for the track hypothesis.",
    "bdt_casc"          => "BDT score(s) for the cascade hypothesis.",
)

"""
    describe_dst_branch(name) :: Union{String, Missing}

Look up the description of a DST `T`-tree top-level branch by name.
Returns `missing` if the name is not in the [`DST_BRANCHES`](@ref) registry.
"""
describe_dst_branch(name::AbstractString) = get(DST_BRANCHES, String(name), missing)

"""
Per-source-file headers from a DST `headerTree`. Present when multiple
input files have been merged into one DST; provides the original `Head`
header, run number and live time for each source.
"""
struct DSTRunHeaders
    headers::Vector{MCHeader}
    run_numbers::Vector{Int32}
    livetimes_s::Vector{Float64}
end
Base.length(h::DSTRunHeaders) = length(h.run_numbers)
Base.show(io::IO, h::DSTRunHeaders) = print(io, "DSTRunHeaders ($(length(h)) source files)")

"""
DST provenance read from the optional `dst_history` TDirectory.
"""
struct DSTHistory
    input_files::Vector{String}
    command_line::String
end
Base.show(io::IO, h::DSTHistory) =
    print(io, "DSTHistory ($(length(h.input_files)) input files)")

"""
A lazy view over the leaves of a single DST top-level branch for a
specific event. Behaves like a `NamedTuple` (read-only, dot-access,
`propertynames`, `keys`, `haskey`). Backed by the parent LazyTree row so
heterogeneous leaf types are preserved without eager materialisation.
"""
struct DSTBranchView
    _row::Any   # UnROOT LazyEvent for the parent row
    _map::Dict{Symbol, Symbol}   # clean leaf name => underlying LazyTree symbol
end
Base.propertynames(v::DSTBranchView) = Tuple(sort!(collect(keys(getfield(v, :_map)))))
Base.keys(v::DSTBranchView) = propertynames(v)
Base.haskey(v::DSTBranchView, k::Symbol) = haskey(getfield(v, :_map), k)
function Base.getproperty(v::DSTBranchView, name::Symbol)
    name === :_row && return getfield(v, :_row)
    name === :_map && return getfield(v, :_map)
    m = getfield(v, :_map)
    haskey(m, name) || error("DSTBranchView has no field ':$(name)'. Available: $(join(propertynames(v), ", "))")
    getproperty(getfield(v, :_row), m[name])
end
Base.getindex(v::DSTBranchView, name::Symbol) = getproperty(v, name)
function Base.iterate(v::DSTBranchView, state=1)
    ks = propertynames(v)
    state > length(ks) ? nothing : ((ks[state] => getproperty(v, ks[state])), state + 1)
end
Base.length(v::DSTBranchView) = length(getfield(v, :_map))
function Base.show(io::IO, v::DSTBranchView)
    ks = propertynames(v)
    print(io, "DSTBranchView(", join(ks, ", "), ")")
end

"""
A single DST entry. Top-level branches of the `T` tree are exposed as
properties:

- For composite branches (multiple leaves), the property returns a
  [`DSTBranchView`](@ref): a lazy NamedTuple-like view onto the leaves
  (e.g. `e.sum_mc_evt.weight`, `e.sum_mc_trks.tmuon_E`, `e.crkv_hits.nhits`).
- For scalar branches (a single value per event, e.g. `bdt_trk`), the
  property returns the value directly (e.g. `e.bdt_trk`).

The list of available branches is dynamic; query with `propertynames(e)`
or via the parent [`DSTTree`](@ref). Use [`describe_dst_branch`](@ref) to
look up the meaning of well-known branch names.
"""
struct DSTEvent
    _idx::Int
    _t::Any   # the underlying LazyTree
    _branches::Dict{Symbol, NamedTuple{(:scalar, :leaves), Tuple{Bool, Vector{Pair{Symbol, Symbol}}}}}
end
Base.propertynames(e::DSTEvent) = Tuple(sort!(collect(keys(getfield(e, :_branches)))))
function Base.getproperty(e::DSTEvent, name::Symbol)
    name === :_idx       && return getfield(e, :_idx)
    name === :_t         && return getfield(e, :_t)
    name === :_branches  && return getfield(e, :_branches)
    bs = getfield(e, :_branches)
    haskey(bs, name) || error("DSTEvent has no branch ':$(name)'. Available: $(join(propertynames(e), ", "))")
    info = bs[name]
    row = getfield(e, :_t)[getfield(e, :_idx)]
    if info.scalar
        return getproperty(row, first(first(info.leaves)))
    else
        m = Dict{Symbol, Symbol}(last(p) => first(p) for p ∈ info.leaves)
        return DSTBranchView(row, m)
    end
end
function Base.show(io::IO, e::DSTEvent)
    print(io, "DSTEvent (idx=$(getfield(e, :_idx)), $(length(propertynames(e))) branches)")
end

"""
Lazy access to the DST summary tree (`T`) of a KM3NeT DST ROOT file.

The DST schema varies between productions: not every branch is
guaranteed to be present, and additional branches may be introduced. The
`DSTTree` does not enforce a schema; every top-level branch found in
`T` is exposed via the corresponding property on each [`DSTEvent`](@ref).
For descriptions of well-known branch names see [`DST_BRANCHES`](@ref)
and [`describe_dst_branch`](@ref).
"""
struct DSTTree{T}
    _fobj::UnROOT.ROOTFile
    header::Union{MCHeader, Missing}
    head_dir::Union{MCHeader, Nothing}
    run_headers::Union{DSTRunHeaders, Nothing}
    history::Union{DSTHistory, Nothing}
    _t::T
    _branches::Dict{Symbol, NamedTuple{(:scalar, :leaves), Tuple{Bool, Vector{Pair{Symbol, Symbol}}}}}

    function DSTTree(fobj::UnROOT.ROOTFile)
        tpath = TTREE_DST_SUMMARY
        T_ = fobj[tpath]
        toplevels = collect(keys(T_))
        all_paths = UnROOT.getbranchnamesrecursive(T_)

        branch_paths = Any[]
        branches = Dict{Symbol, NamedTuple{(:scalar, :leaves), Tuple{Bool, Vector{Pair{Symbol, Symbol}}}}}()

        for tl ∈ toplevels
            leaves_for_tl = filter(p -> p == tl || startswith(p, "$tl/"), all_paths)
            if length(leaves_for_tl) == 1 && first(leaves_for_tl) == tl
                # Scalar top-level branch (e.g. "bdt_trk").
                push!(branch_paths, tl)
                sym = Symbol(tl)
                branches[sym] = (scalar=true, leaves=[sym => sym])
            else
                pairs = Pair{Symbol, Symbol}[]
                for path ∈ leaves_for_tl
                    clean = _clean_dst_leaf_name(tl, path)
                    flat  = Symbol("__$(tl)__$(clean)")
                    rgx   = Regex("^" * _escape_branch_path(path) * "\$")
                    push!(branch_paths, rgx => SubstitutionString(string(flat)))
                    push!(pairs, flat => Symbol(clean))
                end
                branches[Symbol(tl)] = (scalar=false, leaves=pairs)
            end
        end

        t = UnROOT.LazyTree(fobj, tpath, branch_paths)

        header = "Head" ∈ keys(fobj) ? MCHeader(fobj["Head"]) : missing
        head_dir = TDIRECTORY_DST_HEADDIR ∈ keys(fobj) ?
            _read_dst_headdir(fobj) : nothing
        run_headers = TTREE_DST_HEADER ∈ keys(fobj) ?
            _read_dst_run_headers(fobj) : nothing
        history = TDIRECTORY_DST_HISTORY ∈ keys(fobj) ?
            _read_dst_history(fobj) : nothing

        new{typeof(t)}(fobj, header, head_dir, run_headers, history, t, branches)
    end
end
DSTTree(filename::AbstractString) = DSTTree(UnROOT.ROOTFile(filename))

"""
Names of all top-level branches present in the DST `T` tree.
"""
branchnames(t::DSTTree) = sort!(collect(keys(t._branches)))

Base.close(t::DSTTree) = close(t._fobj)
Base.length(t::DSTTree) = length(t._t)
Base.size(t::DSTTree) = (length(t),)
Base.firstindex(::DSTTree) = 1
Base.lastindex(t::DSTTree) = length(t)
Base.eltype(::DSTTree) = DSTEvent
function Base.iterate(t::DSTTree, state=1)
    state > length(t) ? nothing : (t[state], state+1)
end
function Base.show(io::IO, t::DSTTree)
    print(io, "DSTTree ($(length(t)) events, $(length(t._branches)) branches)")
end

"""
    function Base.getindex(t::DSTTree, b::AbstractString, ::Colon)

Shortcut for raw access to a DST `T`-tree branch path.
"""
function Base.getindex(t::DSTTree, b::AbstractString, ::Colon)
    UnROOT.array(t._fobj, TTREE_DST_SUMMARY * "/" * b)
end
Base.getindex(t::DSTTree, r::UnitRange) = [t[i] for i ∈ r]
Base.getindex(t::DSTTree, mask::BitArray) = [t[i] for (i, sel) ∈ enumerate(mask) if sel]
function Base.getindex(t::DSTTree, idx::Integer)::DSTEvent
    idx > length(t) && throw(BoundsError(t, idx))
    DSTEvent(idx, t._t, t._branches)
end


# Build a clean per-leaf accessor symbol for a top-level branch's
# sub-path. Strips the leading `tl/` prefix, deduplicates `<seg>.` /
# `<seg>/` repetitions (typical of split-class branches), drops `[N]`
# suffixes, replaces `/` and `.` with `_`.
function _clean_dst_leaf_name(tl::AbstractString, path::AbstractString)
    rest = path[length(tl) + 2 : end]              # drop "tl/"
    # Drop a leading "<tl>." duplication (e.g. "crkv_hits.nhits[3]" -> "nhits[3]")
    startswith(rest, tl * ".") && (rest = rest[length(tl) + 2 : end])
    segs = split(rest, '/')
    cleaned = String[]
    for seg ∈ segs
        if !isempty(cleaned)
            prev = last(cleaned)
            if startswith(seg, prev * ".")          # "tmuon/tmuon.E" -> cleaned "tmuon", seg "tmuon.E" -> "E"
                seg = seg[length(prev) + 2 : end]
            end
        end
        push!(cleaned, seg)
    end
    name = join(cleaned, "_")
    name = replace(name, r"\[\d+\]$" => "")          # drop fixed-array length suffix
    name = replace(name, '.' => '_')
    name
end

# Escape a ROOT branch path so it can be used as the body of an exact
# Regex match for UnROOT's LazyTree branch_paths. We escape the regex
# metacharacters that actually appear in branch paths.
function _escape_branch_path(path::AbstractString)
    out = IOBuffer()
    for c ∈ path
        c ∈ ('.', '/', '[', ']', '(', ')', '+', '*', '?', '\\', '^', '\$', '|') && print(out, '\\')
        print(out, c)
    end
    String(take!(out))
end


function _read_dst_run_headers(fobj::UnROOT.ROOTFile)
    tpath = TTREE_DST_HEADER
    run_numbers = UnROOT.array(fobj, "$(tpath)/runNumber")
    livetimes_s = UnROOT.array(fobj, "$(tpath)/livetime_s")
    keys_per_row = UnROOT.array(fobj, "$(tpath)/Head/map<string,string>/map<string,string>.first")
    vals_per_row = UnROOT.array(fobj, "$(tpath)/Head/map<string,string>/map<string,string>.second")
    headers = [MCHeader(Dict{String,String}(zip(String.(ks), String.(vs))))
               for (ks, vs) ∈ zip(keys_per_row, vals_per_row)]
    DSTRunHeaders(headers, Int32.(run_numbers), Float64.(livetimes_s))
end

# TODO: unit tests for HeadDir reading are missing, pending a small
# sample DST file in KM3NeTTestData that contains a HeadDir TDirectory.
# Verified manually against
# KM3NeT_00000133_00015285.mc.gsg_astro-neutrinos_merged.sirene.jterbr
# .jppmuon_aashower_static.offline.dst.v9.1.root .
function _read_dst_headdir(fobj::UnROOT.ROOTFile)
    dir = fobj[TDIRECTORY_DST_HEADDIR]
    raw = Dict{String, String}()
    for k ∈ dir.keys
        raw[String(k.fName)] = String(k.fTitle)
    end
    MCHeader(raw)
end

function _read_dst_history(fobj::UnROOT.ROOTFile)
    dir = fobj[TDIRECTORY_DST_HISTORY]
    input_files = String[]
    command_line = ""
    for k ∈ dir.keys
        if k.fName == "input_files"
            input_files = String.(split(k.fTitle, isspace; keepempty=false))
        elseif k.fName == "command_line"
            command_line = String(k.fTitle)
        end
    end
    DSTHistory(input_files, command_line)
end
