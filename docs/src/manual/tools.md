# Tools

There are many commonly used routines to find for example the best reconstructed
muon track or find out if a given hit was flagged by a specific trigger
algorithm. This section will show some helper functions available in `KM3io.jl`.


## Best track/shower

In KM3NeT, the best reconstructed track or shower of a given set of tracks
respectively showers is the one with the highest value of the likelihood
parameter (`lik`) and the longest reconstruction history (`rec_stages`) which is
a record of reconstruction stages performed during the whole fitting procedure.

The offline dataformat, which is used to store reconstruction information, has
only a single `Vector{Trk}` per event which is a flat list of reconstructed
tracks and showers. This vector can be a mix of different reconstruction
algorithms (JGandalf, aashower, FibonacciFit, ...) and different stages of each,
like prefit candidates, intermediate fits and final results. Therefore it is
necessary to take the reconstruction type (`rec_type`) and also the values of
the reconstruction stages (`rec_stages`) into account. Each reconstruction
algorithm and each of their reconstruction stages have their own unique
identifiers, which are stored in these two fields.

!!! note
    Both tracks and showers are stored as `Trk`. This comes from the fact
    that the original KM3NeT dataformat defintion for offline files uses the
    same C++ class (named `Trk`).

The helper functions in `KM3io.jl` to pick the best track/shower always start
with the prefix `best`, followed by the common name of the reconstruction
routine, like `jppmuon`, or `aashower`. For example [`bestjppmuon()`](@ref),
[`bestjppshower()`](@ref) or [`besttrack()`](@ref), latter being a more general
function which gives the possibility to fine tune the selection criteria.

The API documentation of all related functions can be found in the
[Reconstruction](@ref) section.

The input can be an event (`Evt`) or a vector of reconstructed tracks
(`Vector{Trk}`). If no track/shower could be found, `missing` is returned
instead.

Below are some examples of how to use these functions.

```@example 1
using KM3io, KM3NeTTestData

f = ROOTFile(datapath("offline", "km3net_offline.root"))
```

```@example 1
event = f.offline[1]
```

```@example 1
bestjppmuon(event)
```

```@example 1
bestjppshower(event)
```

```@example 1
bestaashower(event)
```

```@example 1
bestjppshower(event.trks)
```

```@example 1
bestaashower(event.trks)
```

Additonally, there are helper functions which can be used to check if a specific
reconstruction stage or result is present in an event or a given set of
tracks/showers.

```@example 1
track = event.trks |> first
```

```@example 1
hasjppmuonprefit(track)
```
```@example 1
hasjppmuonsimplex(track)
```
```@example 1
hasjppmuongandalf(track)
```
```@example 1
hasjppmuonfit(track)
```
```@example 1
hasaashowerfit(track)
```

```@example 1
hasreconstructedjppmuon(event)
```
```@example 1
hasreconstructedjppshower(event)
```
```@example 1
hasreconstructedaashower(event)
```

!!! note
    To check multiple events in one go, use the
    [Broadcasting](https://docs.julialang.org/en/v1/manual/arrays/#Broadcasting)
    feature of the Julia language by putting a dot (`.`) at the end of the
    function name, e.g. `bestjppmuon.(f.offline)` which will find the best Jpp
    muon reconstruction result for each event in the offline tree.

```@example 1
bestjppmuon.(f.offline[2:5])
```

Let's close our file `;)`

```@example 1
close(f)
```

## Trigger masks/flags

KM3NeT uses a 64bit integer type to store information about which triggers have
fired for a given event or hit. The index of the bit which indicates if a
specific trigger has fired is defined in the [KM3NeT
Dataformat](https://git.km3net.de/common/km3net-dataformat) specification which
is used in `KM3io.jl`.

Functions to check if a trigger has fired are for example

- [`is3dmuon()`](@ref)
- [`is3dshower()`](@ref)
- [`ismxshower()`](@ref)
- [`isnb()`](@ref)

which all accept either an event is input or something which has a
`.trigger_mask` field, like a triggered hit.
