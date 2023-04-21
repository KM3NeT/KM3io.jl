![](https://git.km3net.de/common/KM3io.jl/-/raw/main/docs/src/assets/logo.svg)

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

# Installation

`KM3io.jl` is not an officially registered Julia package but it's available via
the [KM3NeT Julia registry](https://git.km3net.de/common/julia-registry). To add
the KM3NeT Julia registry to your local Julia registry list, follow the
instructions in its
[README](https://git.km3net.de/common/julia-registry#adding-the-registry) or simply do

    git clone https://git.km3net.de/common/julia-registry ~/.julia/registries/KM3NeT
    
After that, you can add `KM3io.jl` just like any other Julia package:

    julia> import Pkg; Pkg.add("KM3io")
    
# Quickstart


``` julia-repl
julia> using KM3io, KM3NeTTestData

julia> f = ROOTFile(datapath("offline", "numucc.root"))
ROOTFile{OnlineTree (0 events, 0 summaryslices), OfflineTree (10 events)}

julia> f.offline
OfflineTree (10 events)

julia> some_event = f.offline[3]
KM3io.Evt (3680 hits, 28 MC hits, 38 tracks, 12 MC tracks)

# TODOs

These are mostly low-hanging fruits, so feel free to contribute! `;)`

- [ ] Best track selection (cf. the implementation in [km3io](https://git.km3net.de/km3py/km3io/-/blob/b71300ff1364394d01323a732585f0a8dae303b1/src/km3io/tools.py#L203) or [KM3NeT Dataformat](https://git.km3net.de/common/km3net-dataformat/-/blob/881972133aa0fda809d06c97d9736d346dd35efb/tools/reconstruction.hh#L374), latter being much more closer to the Julia implementation since we don't need all the fancy masking/slicing magic as in Python)
- [ ] Hit calibration for the offline format: fairly straight forward
- [ ] Event+Summaryslice matching: for a given event, return the correct summaryslice to be able to query the most recent PMT rates
- [ ] Optimise type hierarchy
- [ ] Examples!


# Acknowledgements

Thanks for Johannes Schumann for providing the awesome project logo!
