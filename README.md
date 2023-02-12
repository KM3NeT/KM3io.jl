# KM3io.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://common.pages.km3net.de/KM3io.jl/dev)
[![Build Status](https://git.km3net.de/common/KM3io.jl/badges/main/pipeline.svg)](https://git.km3net.de/common/KM3io.jl/pipelines)
[![Coverage](https://git.km3net.de/common/KM3io.jl/badges/main/coverage.svg)](https://git.km3net.de/common/KM3io.jl/commits/main)

`KM3io.jl` is a pure Julia library which implements high-performance I/O
functions and utilities to deal with dataformats used in KM3NeT, e.g. `ROOT`
(online/offline), `detx` and acoustics. In contrast to Python, you are free to
utilise as many (nested) `for`-loops as you like while still being as fast as
C++ counterparts.

The library is still under development so that the API might slightly change.

## Installation

`KM3io.jl` is not an officially registered Julia package but it's
available via the KM3NeT Julia registry. To add the KM3NeT Julia registry,
run:

    git clone https://git.km3net.de/common/julia-registry ~/.julia/registries/KM3NeT

Once the registry is added, Julia will make sure to keep it up to date and pick
it whenever you install a package which is registered there.

To install `KM3io.jl`:

    julia> import Pkg; Pkg.add("KM3io")

## Quickstart

### Reading online (DAQ or RBR) event data

Accessing the data is as easy as opening it via
`OnlineFile("path/to/file.root")` and using indices/slices or iteration.
Everything is lazily loaded so that the data is only occupying memory when it's
actually accessed. In the examples below, we use
**[`KM3NeTTestdata`](https://git.km3net.de/km3py/km3net-testdata)** to get
access to small sample files.

``` julia
julia> using KM3io

julia> using KM3NeTTestData

julia> f = OnlineFile(datapath("online", "km3net_online.root"))
OnlineFile with 3 events

julia> event = f.events[1]
KM3io.DAQEvent with 96 snapshot and 18 triggered hits

julia> event.triggered_hits[4:8]
5-element Vector{KM3io.TriggeredHit}:
 KM3io.TriggeredHit(808447186, 0x00, 30733214, 0x19, 0x0000000000000016)
 KM3io.TriggeredHit(808447186, 0x01, 30733214, 0x15, 0x0000000000000016)
 KM3io.TriggeredHit(808447186, 0x02, 30733215, 0x15, 0x0000000000000016)
 KM3io.TriggeredHit(808447186, 0x03, 30733214, 0x1c, 0x0000000000000016)
 KM3io.TriggeredHit(808451907, 0x07, 30733441, 0x1e, 0x0000000000000004)

julia> for event ∈ f.events
           @show event.header.frame_index length(event.snapshot_hits)
       end
event.header.frame_index = 127
length(event.snapshot_hits) = 96
event.header.frame_index = 127
length(event.snapshot_hits) = 124
event.header.frame_index = 129
length(event.snapshot_hits) = 78
```

