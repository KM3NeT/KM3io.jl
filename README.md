# KM3io.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://common.pages.km3net.de/KM3io.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://common.pages.km3net.de/KM3io.jl/dev)
[![Build Status](https://git.km3net.de/common/KM3io.jl/badges/main/pipeline.svg)](https://git.km3net.de/common/KM3io.jl/pipelines)
[![Coverage](https://git.km3net.de/common/KM3io.jl/badges/main/coverage.svg)](https://git.km3net.de/common/KM3io.jl/commits/main)

`KM3io.jl` is a Julia library which implements high-performance I/O functions
and additional utilities to deal with dataformats used in KM3NeT, e.g.
[ROOT](https://root.cern.ch) (online/offline files),
[DETX](https://wiki.km3net.de/index.php/Dataformats#Detector_Description_.28.detx_and_.datx.29)
(detector geometry and calibrations) and acoustics (waveforms and hardware). In
contrast to Python, you are free to utilise as many (nested) `for`-loops as you
like while still being as fast as in e.g. in C++.

Apropos [ROOT](https://root.cern.ch) and C++, the [KM3NeT
Dataformat](https://git.km3net.de/common/km3net-dataformat) is defined in C++
and uses the I/O functionality of the ROOT framework to create the online and
offline ROOT files. Luckily, there is a pure Julia library named
[UnROOT.jl](https://github.com/JuliaHEP/UnROOT.jl) that provides access the the
ROOT files without the need to install ROOT or the corresponding C++ library.
This allows `KM3io.jl` to be completely free from these external dependencies.

The library is still under development so that the API might slightly change.
Feedback and contributions are highly welcome!

### TODOs

These are mostly low-hanging fruits, so feel free to contribute! `;)`

- [ ] Best track selection (cf. the implementation in [km3io](https://git.km3net.de/km3py/km3io/-/blob/b71300ff1364394d01323a732585f0a8dae303b1/src/km3io/tools.py#L203) or [KM3NeT Dataformat](https://git.km3net.de/common/km3net-dataformat/-/blob/881972133aa0fda809d06c97d9736d346dd35efb/tools/reconstruction.hh#L374), latter being much more closer to the Julia implementation since we don't need all the fancy masking/slicing magic as in Python)
- [ ] Hit calibration for the offline format: fairly straight forward
- [ ] Event+Summaryslice matching: for a given event, return the correct summaryslice to be able to query the most recent PMT rates
- [ ] Examples!

# Installation

`KM3io.jl` is not an officially registered Julia package but it's available via
the [KM3NeT Julia registry](https://git.km3net.de/common/julia-registry). To add
the KM3NeT Julia registry to your local Julia registry list, follow the
instructions in its
[README](https://git.km3net.de/common/julia-registry#adding-the-registry).

# ROOT Files

The two main types of ROOT files in KM3NeT are the online and offline files.
This section describes what they are and how to access them.

## Offline Dataformat

The [offline
dataformat](https://git.km3net.de/common/km3net-dataformat/-/tree/master/offline)
is used to store Monte Carlo (MC) simulations and reconstruction results. The
`OfflineFile` type represents an actual offline file and it is essentially a
vector of events (`Vector{Evt}`) with some fancy caching, lazy access and
slicing magic.

The following REPL session shows how to open a file, access individual events or slices of events, loop through events and access e.g. the tracks which are stored in the events.

``` julia-repl
julia> using KM3io, KM3NeTTestData

julia> f = OfflineFile(datapath("offline", "km3net_offline.root"))
OfflineFile with 10 events

julia> f[5]
KM3io.Evt (83 hits, 0 MC hits, 56 tracks, 0 MC tracks)

julia> f[3:5]
3-element Vector{KM3io.Evt}:
 KM3io.Evt (318 hits, 0 MC hits, 56 tracks, 0 MC tracks)
 KM3io.Evt (157 hits, 0 MC hits, 56 tracks, 0 MC tracks)
 KM3io.Evt (83 hits, 0 MC hits, 56 tracks, 0 MC tracks)

julia> event = f[1]
KM3io.Evt (176 hits, 0 MC hits, 56 tracks, 0 MC tracks)

julia> event.trks[:4]
KM3io.Trk(4, [448.25834890057024, ... , 291.64653112688273, 4000)

julia> event.trks[1:4]
4-element Vector{KM3io.Trk}:
 KM3io.Trk(1, [445.835395997812, ... , 294.6407542676734, 4000)
 KM3io.Trk(2, [445.835395997812, ... , 294.6407542676734, 4000)
 KM3io.Trk(3, [448.136188112227, ... , 294.6407542676734, 4000)
 KM3io.Trk(4, [448.258348900570, ... , 291.64653112688273, 4000)

julia> for event in f
           @show event
       end
event = KM3io.Evt (176 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (125 hits, 0 MC hits, 55 tracks, 0 MC tracks)
event = KM3io.Evt (318 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (157 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (83 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (60 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (71 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (84 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (255 hits, 0 MC hits, 54 tracks, 0 MC tracks)
event = KM3io.Evt (105 hits, 0 MC hits, 56 tracks, 0 MC tracks)
```

## Online Dataformat

The [online
dataformat](https://git.km3net.de/common/km3net-dataformat/-/tree/master/online)
refers to the dataformat which is written by the data acquisition system (DAQ)
of the KM3NeT detectors, more precisely, the ROOT files produced by the
`JDataFilter` which is part of the [`Jpp`](https://git.km3net.de/common/jpp)
framework. The very same format is used in run-by-run (RBR) Monte Carlo (MC)
productions, which mimic the detector response and therefore produce similarly
structured data.

### Event data

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

### Summaryslices and Summary Frames

Summaryslices are generated from timeslices (raw hit data) and are produced by
the DataFilter. A slice contains the data of 100ms and is divided into so-called
frames, each corresponding to the data of a single optical module. Due to the
high amount of data, the storage of timeslices is usually reduced by a factor of
10-100 after the event triggering stage. However, summaryslices are covering the
full data taking period. They however do not contain hit data but only the rates
of the PMTs encoded into a single byte, which therefore is only capable to store
256 different values. The actual rate is calcuated by a helper function (TODO).

The summaryslices are accessible using the `.summaryslices` attribute of the
`OnlineFile` instance:

``` julia
julia> using KM3io, UnROOT, KM3NeTTestData

julia> f = OnlineFile(datapath("online", "km3net_online.root"))
OnlineFile with 3 events

julia> f.summaryslices
KM3io.SummarysliceContainer with 3 summaryslices

julia> for s ∈ f.summaryslices
           @show s.header
       end
s.header = KM3io.SummarysliceHeader(44, 6633, 126, KM3io.UTCExtended(0x5dc6018c, 0x23c34600, false))
s.header = KM3io.SummarysliceHeader(44, 6633, 127, KM3io.UTCExtended(0x5dc6018c, 0x29b92700, false))
s.header = KM3io.SummarysliceHeader(44, 6633, 128, KM3io.UTCExtended(0x5dc6018c, 0x2faf0800, false))
```

To access the actual PMT rates and flags (e.g. for high-rate veto or FIFO
status), the `s.frames` can be used (TODO).
