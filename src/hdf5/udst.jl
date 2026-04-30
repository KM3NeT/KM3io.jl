# H5uDSTFile: HDF5 micro-DST file format for KM3NeT.
#
# A uDST file is a collection of named, typed, 1-D parameter columns stored
# under an HDF5 group (default "/dst"). Each column is one event per row;
# elements may be primitive bits types or NamedTuples of bits types (mapped
# to HDF5 compound datatypes).

const UDST_GROUP = "/dst"
const UDST_SCHEMA_VERSION = 1

# === Schema: per-DST-class NamedTuple definitions ===
# Mirrors the upstream classes documented at
# https://common.pages.km3net.de/aanet/dstpage.html

"""
NamedTuple schema for the `MC_evts_summary` DST class: per-event MC truth
summary including weights, livetimes, generation bounds, and the source MC
run number.
"""
const UDST_MC_EVTS_SUMMARY = @NamedTuple{
    weight::Float32, weight_noOsc::Float32,
    livetime_DAQ::Float32, livetime_sim::Float32,
    n_gen::Int32, E_min_gen::Float32, E_max_gen::Float32, MC_run::Int32,
}

"""
NamedTuple schema for the `MC_hits_summary` DST class: hit count, total
amplitude, and time bounds for the MC hits of an event.
"""
const UDST_MC_HITS_SUMMARY = @NamedTuple{
    nhits::Int32, atot::Float64, tmin::Float64, tmax::Float64,
}

"""
NamedTuple schema for the `hits_summary` DST class: per-event hit count,
total amplitude [pe], time bounds [ns], and DOM/line counts. Used by the
`sum_hits` and `sum_trig_hits` DST branches.
"""
const UDST_HITS_SUMMARY = @NamedTuple{
    nhits::Int32, atot::Float64, tmin::Float64, tmax::Float64,
    ndoms::Int32, nlines::Int32,
}

"""
NamedTuple schema for the `nu_summary` DST class: MC neutrino interaction
summary (Bjorken bx/by, ichan, cc, atmospheric fluxes, oscillation
probabilities, PREM path length).
"""
const UDST_NU_SUMMARY = @NamedTuple{
    bx::Float64, by::Float64, ichan::Float64, cc::Float64,
    atm_flux_numu::Float64, atm_flux_nue::Float64,
    posc_from_numu::Float64, posc_from_nue::Float64,
    atm_flux::Float64, path_length::Float64,
}

"""
NamedTuple schema for the `Cherenkov_hits` DST class (`crkv_hits` branch):
expected Cherenkov hits binned by distance from vertex (per-shell counts at
20m, 50m, 100m, 200m, plus total hits, sumtot, closest, furthest [m]).
"""
const UDST_CHERENKOV_HITS = @NamedTuple{
    nhits::Int32,
    nhits_20m::Int32, nhits_50m::Int32, nhits_100m::Int32, nhits_200m::Int32,
    sumtot::Float64, closest::Float64, furthest::Float64,
}

"""
NamedTuple schema for the `rec_trks_summary` DST class: track reconstruction
summary (track count, cos-zenith bounds, n_within_1deg, up/down counts and
likelihoods). Used by all `sum_jppmuon`, `sum_jpptrack`, `sum_jgandalf`,
`sum_aashower`, `sum_jshower`, and `sum_dusjshower` branches.
"""
const UDST_REC_TRKS_SUMMARY = @NamedTuple{
    ntrks::Int32,
    cos_zenith_min::Float64, cos_zenith_max::Float64,
    n_within_1deg::Int32, n_up::Int32, n_down::Int32,
    max_lik_up::Float64, max_lik_down::Float64,
}

"""
NamedTuple schema for the `jppshower_summary` DST class: prefit/postfit
geometry distance and time, ratio of prefit fits near the best fit, mean
selected-hit time residual, and selected/prefit hit counts.
"""
const UDST_JPPSHOWER_SUMMARY = @NamedTuple{
    prefit_posfit_distance::Float64, prefit_posfit_dt::Float64,
    ratio_prefit_fits_near_best::Float64,
    mean_tres_selected_hits::Float64,
    n_selected_hits::Int32, n_prefit::Int32, n_near_prefit::Int32,
}

"""
NamedTuple schema for the `Celestial_coordinates` DST class (`coords` branch):
J2000 equatorial coordinates (right-ascension and declination [rad]) for the
MC neutrino, the track fit, and the shower fit, plus the modified Julian date.
"""
const UDST_CELESTIAL_COORDINATES = @NamedTuple{
    mjd::Float64,
    nu_ra::Float64, nu_dec::Float64,
    trackfit_ra::Float64, trackfit_dec::Float64,
    showerfit_ra::Float64, showerfit_dec::Float64,
}

"""
Default element types for well-known uDST branch names. Used by `register!`
to resolve `T` when not given explicitly. Append to this dict to register
custom default types for your own branches.
"""
const UDST_BRANCH_TYPES = Dict{Symbol, Type}(
    :sum_mc_evt     => UDST_MC_EVTS_SUMMARY,
    :sum_mc_hits    => UDST_MC_HITS_SUMMARY,
    :sum_hits       => UDST_HITS_SUMMARY,
    :sum_trig_hits  => UDST_HITS_SUMMARY,
    :sum_mc_nu      => UDST_NU_SUMMARY,
    :crkv_hits      => UDST_CHERENKOV_HITS,
    :sum_jppmuon    => UDST_REC_TRKS_SUMMARY,
    :sum_jpptrack   => UDST_REC_TRKS_SUMMARY,
    :sum_jgandalf   => UDST_REC_TRKS_SUMMARY,
    :sum_aashower   => UDST_REC_TRKS_SUMMARY,
    :sum_jshower    => UDST_REC_TRKS_SUMMARY,
    :sum_dusjshower => UDST_REC_TRKS_SUMMARY,
    :sum_jppshower  => UDST_JPPSHOWER_SUMMARY,
    :coords         => UDST_CELESTIAL_COORDINATES,
)

"""
Default human-readable descriptions for well-known uDST branch names. Used
by `register!` to fill the per-dataset `description` attribute when not
given explicitly. Initialised from the ROOT-side `DST_BRANCHES` registry.
"""
const UDST_PARAMETER_DESCRIPTIONS = Dict{Symbol, String}(
    Symbol(k) => v for (k, v) in DST_BRANCHES
)

# === Common parameter sets ===

"""
MC-truth uDST parameter set: the four DST branches that together describe an
event's Monte-Carlo truth (event-level summary, hit-level summary, MC tracks,
neutrino interaction). Use with [`validate`](@ref) to assert that a uDST
contains everything needed for an MC-truth-aware analysis.
"""
const UDST_MC_TRUTH      = Set{Symbol}((:sum_mc_evt, :sum_mc_trks, :sum_mc_hits, :sum_mc_nu))

"""
Hits-related uDST parameter set: total hits, triggered hits, MC hits, and
the per-shell expected Cherenkov-hit summary.
"""
const UDST_HITS          = Set{Symbol}((:sum_hits, :sum_trig_hits, :sum_mc_hits, :crkv_hits))

"""
Track-reconstruction uDST parameter set: the four `rec_trks_summary` branches
covering Jpp muon, Jpp track, JGandalf, and AAShower track hypotheses.
"""
const UDST_RECO_TRACKS   = Set{Symbol}((:sum_jppmuon, :sum_jpptrack, :sum_jgandalf, :sum_aashower))

"""
Shower-reconstruction uDST parameter set: Jpp-shower fit-quality plus
the JShower and Dusj track summaries.
"""
const UDST_RECO_SHOWERS  = Set{Symbol}((:sum_jppshower, :sum_jshower, :sum_dusjshower))

"""
BDT-score uDST parameter set: combined, track-hypothesis, and cascade-hypothesis
BDT scores.
"""
const UDST_BDT           = Set{Symbol}((:bdt, :bdt_trk, :bdt_casc))

"""
Astronomy-related uDST parameter set: J2000 celestial coordinates per event.
"""
const UDST_ASTRO         = Set{Symbol}((:coords,))


# === Types ===

Base.eltype(::H5CompoundDataset{T}) where T = T

"""
A single registered uDST parameter column: a 1-D HDF5 dataset of element
type `T`, with an optional human-readable description stored as an HDF5
attribute on the dataset. Constructed and managed by `H5uDSTFile`; users do
not normally interact with this type directly.
"""
struct H5uDSTParameter{T}
    name::Symbol
    description::Union{String, Missing}
    dset::H5CompoundDataset{T}
end
Base.eltype(::H5uDSTParameter{T}) where T = T

"""
HDF5 micro-DST file: a collection of named, typed, 1-D parameter columns
under a single HDF5 group (default `"/dst"`). Each column holds one element
per event; element types may be primitive bits types or `NamedTuple`s of
bits types (stored as HDF5 compound datatypes).

Open with `H5uDSTFile(filename, mode)`. Modes follow the underlying
`H5File`: `"r"` (read), `"w"` (create/overwrite), `"cw"` (create or open),
`"r+"` (open existing for read/write).

Use `register!` to declare parameters in writeable modes (or pass a
`parameters` list to the constructor), then `push!(f, nt)` to append one
event at a time. Read access is via `f[:name]`, `keys(f)`, `length(f)`.
"""
mutable struct H5uDSTFile
    _h5f::H5File
    _group::String
    _params::Dict{Symbol, H5uDSTParameter}
    _readonly::Bool
    _cache_size::Int
    _lock::ReentrantLock

    function H5uDSTFile(filename::AbstractString, mode::AbstractString="r";
                        group::AbstractString=UDST_GROUP,
                        parameters=nothing,
                        cache_size::Integer=10_000)
        h5f = H5File(filename, mode)
        readonly = (mode == "r")
        # Share the underlying H5File's lock so all access to the file
        # serialises through a single lock.
        f = new(h5f, String(group),
                Dict{Symbol, H5uDSTParameter}(),
                readonly, Int(cache_size), h5f._lock)
        if readonly
            _discover_parameters!(f)
        else
            _ensure_group!(f)
            _discover_parameters!(f)
            if parameters !== nothing
                for spec in parameters
                    _register_from_spec!(f, spec)
                end
            end
        end
        f
    end
end

function _ensure_group!(f::H5uDSTFile)
    h5 = f._h5f._h5f
    if !haskey(h5, f._group)
        HDF5.create_group(h5, f._group)
    end
    grp = h5[f._group]
    if !haskey(attrs(grp), "schema_version")
        attrs(grp)["schema_version"] = UDST_SCHEMA_VERSION
    end
    f
end

function _discover_parameters!(f::H5uDSTFile)
    h5 = f._h5f._h5f
    haskey(h5, f._group) || return f
    grp = h5[f._group]
    for name in keys(grp)
        path = f._group * "/" * name
        obj = h5[path]
        isa(obj, HDF5.Dataset) || continue
        T = eltype(obj)
        desc = haskey(attrs(obj), "description") ? read_attribute(obj, "description") : missing
        cache = H5CompoundDatasetCache(T[], f._cache_size)
        cdset = H5CompoundDataset{T}(obj, cache, f._lock)
        # Only register in the underlying H5File's dataset registry when
        # the file is writeable; read-only datasets must not be flushed.
        f._readonly || (f._h5f._datasets[path] = cdset)
        param = H5uDSTParameter{T}(Symbol(name), desc, cdset)
        f._params[Symbol(name)] = param
    end
    f
end

# Spec dispatch for the constructor's `parameters=...` list.
_register_from_spec!(f::H5uDSTFile, name::Symbol) = register!(f, name)
_register_from_spec!(f::H5uDSTFile, spec::Tuple{Symbol}) = register!(f, spec[1])
_register_from_spec!(f::H5uDSTFile, spec::Tuple{Symbol, <:Type}) = register!(f, spec[1], spec[2])
_register_from_spec!(f::H5uDSTFile, spec::Tuple{Symbol, <:Type, <:AbstractString}) =
    register!(f, spec[1], spec[2]; description=String(spec[3]))
_register_from_spec!(f::H5uDSTFile, spec::Pair{Symbol, <:Type}) =
    register!(f, spec.first, spec.second)


# === API: schema ===

"""
Register a new parameter column on a writeable `H5uDSTFile`.

If `T` is omitted, the type is looked up in [`UDST_BRANCH_TYPES`](@ref).
If `description` is omitted, a default is looked up in
[`UDST_PARAMETER_DESCRIPTIONS`](@ref). Re-registering an existing parameter
with the same type is a no-op; with a different type it errors.
"""
function register!(f::H5uDSTFile, name::Symbol, T::Type=_default_type(name);
                   description::Union{AbstractString, Nothing}=nothing,
                   cache_size::Union{Integer, Nothing}=nothing)
    f._readonly && error("Cannot register parameter ':$(name)': file is read-only")
    isbitstype(T) || error("Parameter type must be isbitstype, got $T (for parameter ':$(name)')")
    if haskey(f._params, name)
        existing_T = eltype(f._params[name])
        existing_T === T || error(
            "Parameter ':$(name)' already registered with type $existing_T, " *
            "tried to re-register with $T"
        )
        return f
    end
    desc = description === nothing ?
        get(UDST_PARAMETER_DESCRIPTIONS, name, missing) : String(description)
    csz = cache_size === nothing ? f._cache_size : Int(cache_size)
    path = f._group * "/" * String(name)
    lock(f._lock)
    try
        cdset = create_dataset(f._h5f, path, T; cache_size=csz)
        ismissing(desc) || (attrs(cdset.dset)["description"] = desc)
        f._params[name] = H5uDSTParameter{T}(name, desc, cdset)
    finally
        unlock(f._lock)
    end
    f
end

function _default_type(name::Symbol)
    haskey(UDST_BRANCH_TYPES, name) || error(
        "No default type for parameter ':$(name)'. " *
        "Pass T explicitly or add an entry to UDST_BRANCH_TYPES."
    )
    UDST_BRANCH_TYPES[name]
end


# === API: writing ===

"""
Append one event to `f`. `nt` must contain values for every registered
parameter (strict mode, the default). With `strict=false`, only the
parameters present in `nt` are advanced -- used for backfilling
newly-registered columns by re-iterating the source events.

Values are coerced to the registered element type:
- primitive types via `convert(T, val)`;
- NamedTuple types via field-name reordering plus per-field `convert`,
  i.e. the input may have its fields in any order, but every field of
  `T` must be present.
"""
function Base.push!(f::H5uDSTFile, nt::NamedTuple; strict::Bool=true)
    f._readonly && error("Cannot push to read-only H5uDSTFile")
    if strict
        _check_strict_keys(f, nt)
    else
        for k in keys(nt)
            haskey(f._params, k) || error(
                "Unknown parameter ':$(k)'. Available: $(sort!(collect(keys(f._params))))"
            )
        end
    end
    lock(f._lock)
    try
        for k in keys(nt)
            param = f._params[k]
            push!(param.dset, _coerce(eltype(param), nt[k]))
        end
    finally
        unlock(f._lock)
    end
    f
end

function _check_strict_keys(f::H5uDSTFile, nt::NamedTuple)
    provided = keys(nt)
    if length(provided) == length(f._params)
        ok = true
        for k in provided
            if !haskey(f._params, k)
                ok = false
                break
            end
        end
        ok && return nothing
    end
    reg = Set(keys(f._params))
    prov = Set(provided)
    miss  = sort!(collect(setdiff(reg, prov)))
    extra = sort!(collect(setdiff(prov, reg)))
    msgs = String[]
    isempty(miss)  || push!(msgs, "missing: $(miss)")
    isempty(extra) || push!(msgs, "unknown: $(extra)")
    error("strict push! mismatch: $(join(msgs, "; "))")
end

# Value coercion. Primitives go through `convert`; NamedTuples are
# reordered to match the registered field order before construction.
_coerce(::Type{T}, val::T) where T = val
_coerce(::Type{T}, val) where T = convert(T, val)
_coerce(::Type{T}, val::NamedTuple) where T <: NamedTuple = T(NamedTuple{fieldnames(T)}(val))
_coerce(::Type{T}, val::Tuple) where T <: NamedTuple = T(val)


# === API: validation ===

"""
Return `true` iff every parameter name in `params` is registered in `f`.
Order is irrelevant. Accepts any iterable of `Symbol`, including
`Set{Symbol}`, `Vector{Symbol}`, a tuple of symbols, or a `NamedTuple`
(its keys are used).
"""
function validate(f::H5uDSTFile, params)
    for p in _to_symbols(params)
        haskey(f._params, p) || return false
    end
    true
end
_to_symbols(s::AbstractSet{Symbol}) = s
_to_symbols(v::AbstractVector{Symbol}) = v
_to_symbols(t::Tuple{Vararg{Symbol}}) = t
_to_symbols(nt::NamedTuple) = keys(nt)

"""
Return `true` iff every registered parameter has the same number of stored
events, counting both on-disk extent and the in-memory write cache. Useful
as a sanity check after a partial-push backfill of a new column.
"""
function validate_lengths(f::H5uDSTFile)
    isempty(f._params) && return true
    first_len = -1
    for p in values(f._params)
        n = _total_length(p)
        first_len == -1 && (first_len = n)
        n == first_len || return false
    end
    true
end

_total_length(p::H5uDSTParameter) = _total_length(p.dset)
function _total_length(d::H5CompoundDataset)
    current_dims, _ = HDF5.get_extent_dims(d.dset)
    first(current_dims) + length(d.cache)
end


# === API: reading ===

Base.keys(f::H5uDSTFile) = sort!(collect(keys(f._params)))
Base.haskey(f::H5uDSTFile, name::Symbol) = haskey(f._params, name)

function Base.length(f::H5uDSTFile)
    isempty(f._params) && return 0
    n = 0
    for p in values(f._params)
        n = max(n, _total_length(p))
    end
    n
end

"""
Return the full vector of values stored for parameter `name`. In writeable
modes the parameter's cache is flushed first so the returned vector
reflects every value pushed so far.
"""
function Base.getindex(f::H5uDSTFile, name::Symbol)
    haskey(f._params, name) || error("No parameter ':$(name)'. Available: $(keys(f))")
    p = f._params[name]
    f._readonly || flush(p.dset)
    read(p.dset.dset)
end

"""
Description string registered for parameter `name`, or `missing` if none
is stored.
"""
function description(f::H5uDSTFile, name::Symbol)
    haskey(f._params, name) || error("No parameter ':$(name)'")
    f._params[name].description
end

"""
All HDF5 attributes attached to the dataset for parameter `name`, returned
as a `Dict{String, Any}`.
"""
function metadata(f::H5uDSTFile, name::Symbol)
    haskey(f._params, name) || error("No parameter ':$(name)'")
    dset = f._params[name].dset.dset
    Dict{String, Any}(k => read_attribute(dset, k) for k in keys(attrs(dset)))
end


# === Lifecycle ===

function Base.flush(f::H5uDSTFile)
    for p in values(f._params)
        flush(p.dset)
    end
    f
end

function Base.close(f::H5uDSTFile)
    f._readonly || flush(f)
    close(f._h5f)
    nothing
end

function Base.show(io::IO, f::H5uDSTFile)
    n = length(f._params)
    nev = isempty(f._params) ? 0 : length(f)
    rw = f._readonly ? "r" : "rw"
    print(io, "H5uDSTFile($(n) parameters, $(nev) events, group=\"$(f._group)\", $rw)")
end
