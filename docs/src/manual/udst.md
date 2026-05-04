# uDST (HDF5)

A *uDST* (micro-DST) is a compact, columnar HDF5 file holding one row per
event with a user-defined set of parameters. It mirrors the `T` parameter
tree of a ROOT-based KM3NeT [DST file](@ref dst_format) (see also the
upstream [DST documentation](https://common.pages.km3net.de/aanet/dstpage.html)),
but stored in HDF5 and without the `E` event tree. uDSTs are intended for
end-of-pipeline analysis files where a fast columnar scan is more useful
than full per-event hit/track records.

## On-disk layout

By default, every parameter is stored as a 1-D dataset under the HDF5
group `/dst/`:

```
file.h5
  /KM3io.jl                     (root attribute: package version)
  /dst                          (group, attribute: schema_version)
    bdt_score                   (1-D Float64 dataset, attr: description=...)
    crkv_hits                   (1-D compound dataset, attr: description=...)
    coords                      (1-D compound dataset, attr: description=...)
    ...
```

Each dataset's element type may be:

- a **primitive** bits type (`Int32`, `Float64`, `Bool`, ...), or
- a **`NamedTuple`** of bits types, stored as an HDF5 compound datatype
  (one element per event holds all the named fields).

Per-parameter human-readable descriptions are stored as HDF5 attributes
on the dataset, so generic HDF5 tooling (Python's `h5py`, `h5dump`, etc.)
can introspect them without KM3io.

The default group is configurable via the `group=` keyword: you can hold
several uDSTs in a single HDF5 file (e.g. one group per analysis stage)
by giving each [`H5uDSTFile`](@ref) a different group path.

## API at a glance

The `H5uDSTFile` API is small and centred on one type:

```julia
using KM3io

f = H5uDSTFile("out.h5", "w"; parameters = [
    (:bdt_score, Float64, "BDT track/cascade score"),
    :crkv_hits,                                 # type from UDST_BRANCH_TYPES
    :coords,
])

for evt in events
    push!(f, (
        bdt_score = score(evt),
        crkv_hits = compute_crkv_summary(evt),
        coords    = compute_celestial_coords(evt),
    ))
end
close(f)
```

Reading is symmetric:

```julia
g = H5uDSTFile("out.h5")
g[:bdt_score]                # Vector{Float64}
g[:crkv_hits][1].nhits       # NamedTuple field access
length(g)                    # number of events
keys(g)                      # registered parameter names
description(g, :crkv_hits)   # the stored description
metadata(g, :crkv_hits)      # all HDF5 attributes as Dict{String,Any}
close(g)
```

The main entry points exported by KM3io are:

| Function / type                | Purpose                                                      |
|--------------------------------|--------------------------------------------------------------|
| [`H5uDSTFile`](@ref)           | Open / create a uDST file (`"r"`, `"w"`, `"cw"`, `"r+"`)     |
| [`register!`](@ref)            | Declare a parameter column on a writeable file               |
| `push!`                        | Append one event (strict by default; `strict=false` allows partial pushes for backfilling new columns) |
| [`validate`](@ref)             | Check that a uDST registers a given set of parameter names   |
| [`validate_lengths`](@ref)     | Check that all columns have the same number of events        |
| [`description`](@ref)          | Read a parameter's stored description                         |
| [`metadata`](@ref)             | Read all HDF5 attributes attached to a parameter dataset     |

Strict-mode `push!` is the default: every event must provide values for
every registered parameter, which keeps all columns aligned by
construction. `strict = false` is reserved for the *rewind* workflow:
adding a new column to an already-populated uDST and filling it by
re-iterating the source events.

## Predefined schemas and parameter sets

KM3io ships ready-made `NamedTuple` aliases for the well-known DST
classes documented at
<https://common.pages.km3net.de/aanet/dstpage.html>:

| Branch (Symbol)                                                        | KM3io alias                          |
|------------------------------------------------------------------------|--------------------------------------|
| `:sum_mc_evt`                                                          | [`UDST_MC_EVTS_SUMMARY`](@ref)       |
| `:sum_mc_hits`                                                         | [`UDST_MC_HITS_SUMMARY`](@ref)       |
| `:sum_hits`, `:sum_trig_hits`                                          | [`UDST_HITS_SUMMARY`](@ref)          |
| `:sum_mc_nu`                                                           | [`UDST_NU_SUMMARY`](@ref)            |
| `:crkv_hits`                                                           | [`UDST_CHERENKOV_HITS`](@ref)        |
| `:sum_jppmuon`, `:sum_jpptrack`, `:sum_jgandalf`, `:sum_aashower`, `:sum_jshower`, `:sum_dusjshower` | [`UDST_REC_TRKS_SUMMARY`](@ref)      |
| `:sum_jppshower`                                                       | [`UDST_JPPSHOWER_SUMMARY`](@ref)     |
| `:coords`                                                              | [`UDST_CELESTIAL_COORDINATES`](@ref) |

The branch-name -> type mapping lives in [`UDST_BRANCH_TYPES`](@ref);
default human-readable descriptions live in
[`UDST_PARAMETER_DESCRIPTIONS`](@ref) (initialised from the ROOT-side
[`DST_BRANCHES`](@ref) registry). Both dicts are extensible at runtime:
just append your own branch names. With those entries in place,
`register!(f, :name)` resolves both the type and the description
without any further arguments.

For asserting that a uDST contains the parameters expected by a
downstream analysis, KM3io provides a few `Set{Symbol}` constants:
[`UDST_MC_TRUTH`](@ref), [`UDST_HITS`](@ref), [`UDST_RECO_TRACKS`](@ref),
[`UDST_RECO_SHOWERS`](@ref), [`UDST_BDT`](@ref), [`UDST_ASTRO`](@ref).
Use them with [`validate`](@ref):

```julia
validate(f, UDST_MC_TRUTH)        # true iff the four MC-truth branches are all registered
```

## Examples

A full, executable walkthrough -- including imperative versus declarative
schema declaration, NamedTuple compound parameters, append-events on
existing files, the rewind workflow for backfilling new columns, validation,
custom group paths, and an end-to-end sketch deriving a uDST from an
[`OfflineEventTape`](@ref) -- lives in [Writing uDSTs](@ref).
