# KM3io.jl

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

!!! note

    The library is still under development so that the API might slightly change.
    Feedback and contributions are highly welcome!

## Installation

`KM3io.jl` is **not an officially registered Julia package** but it's available via
the **[KM3NeT Julia registry](https://git.km3net.de/common/julia-registry)**. To add
the KM3NeT Julia registry to your local Julia registry list, follow the
instructions in its
[README](https://git.km3net.de/common/julia-registry#adding-the-registry) or simply do

    git clone https://git.km3net.de/common/julia-registry ~/.julia/registries/KM3NeT
    
After that, you can instal `KM3io.jl` just like any other Julia package:

    julia> import Pkg; Pkg.add("KM3io")
    
!!! note

    If you encounter the error `UndefVarError: libhdf5 not defined`, you are probably
    using an M1 or M2 Mac computer. There is an issue with `HDF5.jll` due to a missing
    precompiled `libhdf5` artifact for the M1 and M2 architectures, so you need to
    install it manually and set an envrionment variable before starting Julia.
    You can easily install `hdf5lib` using e.g. `brew`:
    
        brew install hdf5
        
    and then set the environment variable `JULIA_HDF5_PATH` to point to the location
    of the HDF5 files (put this line into your `~/.bashrc` or `~/.zshrc` or whatever
    shell you use):
    
        export JULIA_HDF5_PATH=/opt/homebrew/Cellar/hdf5/1.12.2_2
        
    Make sure that the path is correct, you might have a different version number.
    
## Quickstart


``` julia-repl
julia> using KM3io, KM3NeTTestData

julia> f = ROOTFile(datapath("offline", "numucc.root"))
ROOTFile{OnlineTree (0 events, 0 summaryslices), OfflineTree (10 events)}

julia> f.offline
OfflineTree (10 events)

julia> some_event = f.offline[3]
KM3io.Evt (3680 hits, 28 MC hits, 38 tracks, 12 MC tracks)
```

## Acknowledgements

Thanks to [Johannes Schumann](https://git.km3net.de/jschumann) for providing the awesome project logo!
