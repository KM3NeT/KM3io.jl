# Auxiliary Files

There are a bunch of auxiliary file formats in KM3NeT which are used in
different stages of processing and calibration procedures. `KM3io.jl`
supports many of them by defining a container type and extending the
`Base.read` function so that the general pattern is:

```
f = read("path/to/the.file", FileContainerType)
```

## Interoperability with `KM3Aux.jl`

The [`KM3Aux.jl`](https://git.km3net.de/common/KM3Aux.jl) package provides
easy access to the auxiliary [KM3NeT Auxiliary Files Archive](https://git.km3net.de/auxiliary_data/calibration).
In addition to that, once `KM3Aux` is loaded together with `KM3io`,
additional methods will become available using the extension feature of Julia.

- [`getpmts(det_id, run)`](@ref)
- [`gettripods(det_id, run)`](@ref)
- [`gethydrophones(det_id, run)`](@ref)
- [`getwaveforms(det_id, run)`](@ref)

## File types

### PMT File

The container type [`PMTFile`](@ref) is used to load PMT files which are produced
by the K40 calibration procedure in Jpp.

Below is an example, using a PMT file from the
[`KM3NeTTestData.jl`](https://git.km3net.de/km3py/km3net-testdata) package.

```@example 1
using KM3io
using KM3NeTTestData

pmtfile = read(datapath("pmt", "calibration_00000117_H_1.0.0_00013757_00013826_1.txt"), PMTFile)
```

Data for individual PMTs can be accessed by indexing using the module ID and the DAQ channel ID of the PMT:

```@example 1
pmtdata = pmtfile[806451572, 4]
pmtdata.gain
```

The returned type is [`PMTData`](@ref) with following fields:

```@example 1
fieldnames(typeof(pmtdata))
```
