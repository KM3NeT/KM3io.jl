# Writing uDSTs

A *uDST* (micro-DST) is a compact, columnar HDF5 file holding one row per
event with a user-defined set of parameters. Conceptually it mirrors the
`T` parameter tree of a ROOT-based KM3NeT DST file (see the upstream
[DST documentation](https://common.pages.km3net.de/aanet/dstpage.html)),
but stored in HDF5 and without the `E` event tree.

KM3io exposes uDSTs through the [`H5uDSTFile`](@ref) type. Each
*parameter* is a 1-D dataset under an HDF5 group (default `/dst/`), and
each event appends one element to every dataset. Element types may be:

- a **primitive** bits type (`Int32`, `Float64`, `Bool`, ...), or
- a **`NamedTuple`** of bits types, stored as an HDF5 compound datatype
  (one element per event holds all the named fields).

This page walks through writing, reading, appending and backfilling
uDSTs, with examples for each.

## A first uDST

The shortest path to a uDST is to declare the schema upfront and `push!`
events one by one:

```@example udst
using KM3io

fname = tempname() * ".h5"

f = H5uDSTFile(fname, "w"; parameters = [
    (:bdt_score, Float64, "BDT track/cascade score"),
    (:n_doms,    Int32,   "Number of triggered DOMs"),
])

for i in 1:5
    push!(f, (bdt_score = 0.1 * i, n_doms = Int32(10 + i)))
end

close(f)
```

That produces an HDF5 file with the layout

```
file.h5
  /dst                          (group)
    bdt_score                   (1-D Float64 dataset, attr: description=...)
    n_doms                      (1-D Int32 dataset,   attr: description=...)
```

Reading it back is symmetric:

```@example udst
g = H5uDSTFile(fname)
@show keys(g)
@show length(g)
@show g[:bdt_score]
@show g[:n_doms]
close(g)
```

`keys(g)` returns the registered parameter names, `length(g)` is the
number of events, and `g[:name]` returns the full vector.

!!! note
    Always `close(f)` after writing. KM3io buffers writes in a per-parameter
    cache to amortise HDF5 dataset extensions; closing the file (or calling
    `flush(f)`) flushes those caches to disk. Forgetting to close means
    losing whatever is still in memory.

## Two ways to declare parameters

You can pre-register everything in the constructor:

```@example udst
f = H5uDSTFile(tempname() * ".h5", "w"; parameters = [
    (:energy, Float64, "Reconstructed energy [GeV]"),
    (:zenith, Float64, "Reconstructed zenith [rad]"),
])
close(f)
```

or register parameters imperatively after opening:

```@example udst
f = H5uDSTFile(tempname() * ".h5", "w")
register!(f, :energy, Float64; description = "Reconstructed energy [GeV]")
register!(f, :zenith, Float64; description = "Reconstructed zenith [rad]")
close(f)
```

Both styles can be mixed in the same file. `register!` returns `f`, so it
chains naturally if you prefer that.

The accepted spec forms in the `parameters = [...]` constructor argument
are:

| Spec form                         | Meaning                                          |
|-----------------------------------|--------------------------------------------------|
| `:name`                           | Type and description from the registries        |
| `(:name,)`                        | Same as above                                    |
| `(:name, T)`                      | Explicit type, description from the registry     |
| `(:name, T, "description")`       | Explicit type and description                    |
| `:name => T`                      | Pair form, explicit type                         |

## Pushing events: strict by default

`push!(f, nt)` is *strict*: every registered parameter must appear as a
key in the NamedTuple, and every key must be a registered parameter.
This keeps all columns the same length by construction.

```@example udst
f = H5uDSTFile(tempname() * ".h5", "w"; parameters = [
    (:a, Int32),
    (:b, Float64),
])

push!(f, (a = Int32(1), b = 2.0))           # ok
try
    push!(f, (a = Int32(2),))               # missing :b
catch err
    @show err
end
try
    push!(f, (a = Int32(3), b = 4.0, c = 5.0))   # unknown :c
catch err
    @show err
end

close(f)
```

A relaxed mode (`strict = false`) is available for backfilling new
columns; see the [Adding a new column](#Adding-a-new-column-(rewind))
section below.

## Compound parameters: NamedTuple columns

For grouped quantities like the per-event Cherenkov-hit summary
(`crkv_hits` in the upstream DST schema, which has 8 fields), declare a
NamedTuple type and pass values as NamedTuples per event. KM3io ships
ready-made type aliases for the well-known DST classes:

```@example udst
fname = tempname() * ".h5"
f = H5uDSTFile(fname, "w"; parameters = [
    :crkv_hits,                    # type from UDST_BRANCH_TYPES (= UDST_CHERENKOV_HITS)
    :coords,                       # = UDST_CELESTIAL_COORDINATES
    (:bdt, Float32, "Track/cascade BDT score"),
])

for i in 1:3
    push!(f, (
        crkv_hits = (
            nhits      = Int32(10 + i),
            nhits_20m  = Int32(2),
            nhits_50m  = Int32(4),
            nhits_100m = Int32(6),
            nhits_200m = Int32(8),
            sumtot     = 12.5 * i,
            closest    = 1.0,
            furthest   = 100.0,
        ),
        coords = (
            mjd = 58849.0 + i,
            nu_ra = 0.1, nu_dec = 0.2,
            trackfit_ra = 0.11, trackfit_dec = 0.21,
            showerfit_ra = 0.12, showerfit_dec = 0.22,
        ),
        bdt = Float32(0.1 * i),
    ))
end

close(f)
```

Each compound parameter is stored as a single 1-D dataset whose elements
are HDF5 compound records. On read, every event materialises as a
`NamedTuple` of the original field names and types:

```@example udst
g = H5uDSTFile(fname)
events = g[:crkv_hits]
@show typeof(events)
@show events[2]
@show events[2].nhits, events[2].sumtot
close(g)
```

!!! tip "Field order is irrelevant"
    The fields of the value you push may be in any order; KM3io reorders
    and converts per-field to match the registered NamedTuple type. The
    only requirement is that every field of the registered type is
    present in the input.

```@example udst
f = H5uDSTFile(tempname() * ".h5", "w"; parameters = [:crkv_hits])
push!(f, (crkv_hits = (
    sumtot = 99.0, furthest = 50.0, closest = 1.0,    # arbitrary order
    nhits = Int32(7),
    nhits_200m = Int32(11), nhits_100m = Int32(8),
    nhits_50m = Int32(5),  nhits_20m = Int32(2),
),))
close(f)
```

### Defining your own compound parameter

`UDST_BRANCH_TYPES` covers the well-known DST classes, but any
`isbitstype` NamedTuple works. Define one with `@NamedTuple` and pass it
explicitly to `register!`:

```@example udst
const MyHitSummary = @NamedTuple{
    n_hits::Int32,
    e_min::Float32,
    e_max::Float32,
}

f = H5uDSTFile(tempname() * ".h5", "w")
register!(f, :my_hit_summary, MyHitSummary; description = "Per-event hit summary")
push!(f, (my_hit_summary = (n_hits = Int32(42), e_min = 0.5f0, e_max = 12.3f0),))
close(f)
```

## Reusing the upstream DST schema

KM3io exposes constants mirroring the parameter classes documented at
[dstpage.html](https://common.pages.km3net.de/aanet/dstpage.html):

| Branch (Symbol)    | Upstream class            | KM3io alias                    |
|--------------------|---------------------------|--------------------------------|
| `:sum_mc_evt`      | `MC_evts_summary`         | [`UDST_MC_EVTS_SUMMARY`](@ref) |
| `:sum_mc_hits`     | `MC_hits_summary`         | [`UDST_MC_HITS_SUMMARY`](@ref) |
| `:sum_hits` / `:sum_trig_hits` | `hits_summary` | [`UDST_HITS_SUMMARY`](@ref)    |
| `:sum_mc_nu`       | `nu_summary`              | [`UDST_NU_SUMMARY`](@ref)      |
| `:crkv_hits`       | `Cherenkov_hits`          | [`UDST_CHERENKOV_HITS`](@ref)  |
| `:sum_jppmuon`, `:sum_jpptrack`, `:sum_jgandalf`, `:sum_aashower`, `:sum_jshower`, `:sum_dusjshower` | `rec_trks_summary` | [`UDST_REC_TRKS_SUMMARY`](@ref) |
| `:sum_jppshower`   | `jppshower_summary`       | [`UDST_JPPSHOWER_SUMMARY`](@ref) |
| `:coords`          | `Celestial_coordinates`   | [`UDST_CELESTIAL_COORDINATES`](@ref) |

The mapping from branch name to type is materialised in
[`UDST_BRANCH_TYPES`](@ref); default descriptions live in
[`UDST_PARAMETER_DESCRIPTIONS`](@ref) (initialised from the ROOT-side
[`KM3io.DST_BRANCHES`](@ref) registry).

Both dicts are extensible at runtime: register your own branch names by
appending to them.

```@example udst
KM3io.UDST_BRANCH_TYPES[:my_summary] = MyHitSummary
KM3io.UDST_PARAMETER_DESCRIPTIONS[:my_summary] = "My custom per-event summary"

f = H5uDSTFile(tempname() * ".h5", "w")
register!(f, :my_summary)            # type and description auto-resolved
@show description(f, :my_summary)
close(f)
```

### Predefined parameter sets

For convenience, KM3io ships a few `Set{Symbol}` constants covering
common groupings:

| Constant              | Members                                                                 |
|-----------------------|-------------------------------------------------------------------------|
| `UDST_MC_TRUTH`       | `:sum_mc_evt`, `:sum_mc_trks`, `:sum_mc_hits`, `:sum_mc_nu`             |
| `UDST_HITS`           | `:sum_hits`, `:sum_trig_hits`, `:sum_mc_hits`, `:crkv_hits`             |
| `UDST_RECO_TRACKS`    | `:sum_jppmuon`, `:sum_jpptrack`, `:sum_jgandalf`, `:sum_aashower`       |
| `UDST_RECO_SHOWERS`   | `:sum_jppshower`, `:sum_jshower`, `:sum_dusjshower`                     |
| `UDST_BDT`            | `:bdt`, `:bdt_trk`, `:bdt_casc`                                         |
| `UDST_ASTRO`          | `:coords`                                                               |

These pair naturally with [`validate`](@ref) (see below) for asserting
that a uDST contains all parameters expected by a downstream consumer.

## Reading uDSTs

Open without an explicit mode (defaults to `"r"`):

```@example udst
g = H5uDSTFile(fname)              # the file we wrote earlier
```

Then:

```@example udst
@show keys(g)
@show length(g)
@show haskey(g, :crkv_hits)
@show haskey(g, :nope)
```

Get a column as a `Vector`:

```@example udst
@show g[:bdt][1:3]
```

Read a parameter's description:

```@example udst
@show description(g, :crkv_hits)
```

Read all attributes attached to a parameter as a `Dict{String, Any}`:

```@example udst
@show metadata(g, :crkv_hits)
close(g)
```

Attributes other than `description` are not interpreted by KM3io; you can
attach any HDF5-supported attribute to the dataset directly through its
underlying `H5CompoundDataset`, and read them back via `metadata`.

## Appending events to an existing file

To extend an existing uDST with more events, open it with `"r+"`:

```@example udst
fname2 = tempname() * ".h5"

# Phase 1: write three events.
f = H5uDSTFile(fname2, "w"; parameters = [(:x, Float64), (:n, Int32)])
for i in 1:3
    push!(f, (x = Float64(i), n = Int32(i)))
end
close(f)

# Phase 2: re-open and append three more.
f = H5uDSTFile(fname2, "r+")
@show length(f)
for i in 4:6
    push!(f, (x = Float64(i), n = Int32(i)))
end
close(f)

# Phase 3: read the combined result.
g = H5uDSTFile(fname2)
@show g[:x]
@show g[:n]
close(g)
```

The schema is discovered automatically when re-opening: the parameters
already in the file are immediately available for `push!`.

## Adding a new column (rewind)

A common workflow is to enrich an existing uDST with a new derived
quantity computed by re-iterating the source events. Open the existing
file, register the new column, then push partial events with
`strict = false`:

```@example udst
# Existing file with three rows in :x and :n already.
f = H5uDSTFile(fname2, "r+")
register!(f, :x_squared, Float64; description = "x^2 derived later")

# Source events to re-iterate would normally come from elsewhere
# (an OfflineEventTape, a ROOTFile, a previous DST). Here we use the
# already-stored :x column as a stand-in.
xs = f[:x]
@show length(f), validate_lengths(f)     # x_squared is at length 0 -> false

for x in xs
    push!(f, (x_squared = x^2,); strict = false)
end

@show validate_lengths(f)                # all columns equal length again
close(f)

# Verify.
g = H5uDSTFile(fname2)
@show g[:x_squared]
close(g)
```

Notes on partial pushes:

- Each call to `push!(f, nt; strict = false)` advances **only** the
  parameters mentioned in `nt`. Any registered parameter not in `nt` is
  left untouched.
- All keys in `nt` must be registered; partial mode is not "anything
  goes". Unknown keys still raise.
- After backfilling, [`validate_lengths(f)`](@ref) confirms that every
  column ended up with the same number of events.

You can also fill several new columns in one pass:

```julia
register!(f, :a, Float32)
register!(f, :b, Int32)

for evt in source_events
    push!(f, (a = compute_a(evt), b = compute_b(evt)); strict = false)
end
```

## Validating against a parameter set

[`validate(f, params)`](@ref) returns `true` iff every name in `params` is
registered in `f`. Order is irrelevant. The `params` argument can be any
of `Set{Symbol}`, `Vector{Symbol}`, a tuple of symbols, or a `NamedTuple`
(its keys are used).

```@example udst
f = H5uDSTFile(tempname() * ".h5", "w"; parameters = [
    :sum_mc_evt, :sum_mc_hits, :sum_mc_nu, :crkv_hits, :coords,
])
@show validate(f, [:sum_mc_evt, :sum_mc_nu])         # both registered
@show validate(f, UDST_ASTRO)                        # {:coords}, registered
@show validate(f, [:sum_mc_evt, :sum_jppmuon])       # :sum_jppmuon missing
@show validate(f, UDST_MC_TRUTH)                     # :sum_mc_trks missing
@show validate(f, (:crkv_hits, :coords))             # tuple of symbols
@show validate(f, (sum_mc_evt = nothing, sum_mc_nu = nothing))   # NamedTuple keys
close(f)
```

The fourth call above returns `false` because `UDST_MC_TRUTH` includes
`:sum_mc_trks`, which is not yet in [`UDST_BRANCH_TYPES`](@ref) and was
therefore not registered in this file. To include it, register it
explicitly with your own NamedTuple type, or pre-populate
`UDST_BRANCH_TYPES[:sum_mc_trks]`.

[`validate_lengths(f)`](@ref) is a complementary check: it returns `true`
iff every registered parameter has the same number of stored events.
Useful as the final assertion after a backfill.

## Custom group paths

By default, parameters live under `/dst/`. You can override this with
the `group` keyword to keep multiple parameter collections in one HDF5
file (e.g. one group per analysis stage):

```@example udst
fname3 = tempname() * ".h5"

# Stage 1: reconstruction summary.
f = H5uDSTFile(fname3, "cw"; group = "/reco", parameters = [(:bdt, Float32)])
push!(f, (bdt = 0.42f0,))
close(f)

# Stage 2: oscillation weights, in the same file but a separate group.
f = H5uDSTFile(fname3, "r+"; group = "/oscillations", parameters = [(:weight, Float64)])
push!(f, (weight = 1.234,))
close(f)

# Each group is read back independently.
reco = H5uDSTFile(fname3; group = "/reco")
@show keys(reco), reco[:bdt]
close(reco)

osc = H5uDSTFile(fname3; group = "/oscillations")
@show keys(osc), osc[:weight]
close(osc)
```

A `H5uDSTFile` only sees one group at a time. The two groups are siblings
in the underlying HDF5 file and can also be read directly with the
generic [`H5File`](@ref) or with `HDF5.h5open`.

## End-to-end: deriving a uDST from offline events

A realistic workflow is to iterate an offline ROOT file (or an
[`OfflineEventTape`](@ref) over many files) and emit one uDST row per
event. The skeleton is always the same:

```julia
using KM3io

function build_udst(rootfiles, out::AbstractString)
    f = H5uDSTFile(out, "w"; parameters = [
        (:run_id,     Int32,  "Run number"),
        (:event_id,   Int64,  "Event ID within the run"),
        (:n_hits,     Int32,  "Number of triggered hits"),
        :crkv_hits,
        (:bdt_score,  Float32, "Track/cascade BDT score"),
    ])

    tape = OfflineEventTape(rootfiles...)
    for evt in tape
        trk = bestjppmuon(evt)
        trk === nothing && continue

        push!(f, (
            run_id    = Int32(evt.run_id),
            event_id  = Int64(evt.id),
            n_hits    = Int32(length(evt.hits)),
            crkv_hits = compute_crkv_summary(evt, trk),
            bdt_score = compute_bdt(evt, trk),
        ))
    end

    close(f)
end
```

`compute_crkv_summary` and `compute_bdt` are user-supplied; the former
must return a NamedTuple compatible with [`UDST_CHERENKOV_HITS`](@ref).

Once the file is written, downstream code consumes it as a flat
column store:

```julia
f = H5uDSTFile("derived.udst.h5")
mask = f[:bdt_score] .> 0.7
selected_event_ids = f[:event_id][mask]
close(f)
```

## Cheat sheet

```
# open
f = H5uDSTFile("file.h5", "w"; parameters = [...])     # create
f = H5uDSTFile("file.h5")                              # read ("r")
f = H5uDSTFile("file.h5", "r+")                        # append
f = H5uDSTFile("file.h5", "cw"; group = "/dst2")       # create-or-open custom group

# schema
register!(f, :name)                                    # auto type + description
register!(f, :name, T; description = "...")           # explicit
validate(f, UDST_MC_TRUTH)                             # subset check

# write
push!(f, (a = ..., b = ...))                           # strict
push!(f, (c = ...,); strict = false)                   # partial / backfill
flush(f); close(f)

# read
keys(f); length(f); haskey(f, :name)
f[:name]                                               # full Vector
description(f, :name); metadata(f, :name)
validate_lengths(f)
```
