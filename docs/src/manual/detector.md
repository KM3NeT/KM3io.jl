# Detector and its Components

In this example, we will explore the components of a KM3NeT detector, which is
represented by the [`Detector`](@ref) type in `KM3io.jl`. The detector
description is stored in so-called
[`DETX`-files](https://wiki.km3net.de/index.php/Dataformats#Detector_Description_.28.detx_and_.datx.29),
named after its filename extension `.detx`). It's an ASCII-based file format and
by the time of writing this example, `v5` is the latest format version. There is
a yet unofficial binary version of this format named `DATX` (with the filename
extension `datx`), which is currently not supported, neither widely used in
KM3NeT.

!!! note

    `KM3io.jl` offers conversions between the different `DETX` format versions.
    Typically, each major version brings a new set of parameters. Downgrading
    is therefore not lossless. When when upgrading from one version to another,
    the new parameters needs to be
    filled in. Some of these can be calculated from existing ones, like
    the module position, which was introduced in `v4` and is equal to the crossing
    point of the PMT axes. Otherwise, these parameters are either set to meaningful
    default values or to `missing`.
    
## Loading a `DETX` File

The [`Detector`](@ref) type offers a constructor which takes a filepath to a `DETX`
file. The [KM3NeTTestData.jl](https://git.km3net.de/km3py/km3net-testdata)
offers a collection of detector sample files, so let's pick one of them:

```@example 1
using KM3io, KM3NeTTestData

det = Detector(datapath("detx", "detx_v5.detx"))
```

A detector configuration (format version 5) has been loaded with 6 strings
(sometimes also called detection unit or DU) holding a total 114 modules.

## Accessing Modules

### Iterating over all modules

There are multiple ways to access modules within a [`Detector`](@ref). One of
them is iterating over it, which yields [`DetectorModule`](@ref) instances in no
specific order:

```@example 1
for m in det
    println(m)
end
```

!!! warning

    `module` is a reserved keyword in Julia and `mod` is the "modulo function",
    so keep this in mind when chosing a variable name for a [`DetectorModule`](@ref).
    Most of the time `m` is fine, or just be verbose with `detector_module` and use
    your editors tab-completion.

As we can see in the output, there are two types of modules: optical modules and
base modules. The main difference between the two in the detector file context
is that base modules do not contain PMTs and are always sitting on floor 0.

!!! note

    Although iterating over a [`Detector`](@ref) feels like iterating over a vector, accessing
    single elements via `det[idx]` will not work as such since it requires
    the `idx` to be a module ID. This design was chosen since the detector dataformat
    specification does not specify module ordering, so there is no such thing as the
    "n-th module".
    Accessing modules by their module ID however is the standard use case, see below.

### Modules via "module ID"

Modules have a unique identification number called module ID (sometimes also
called "DOM ID", where DOM stands for "Digital Optical Module") and we can use
this ID to access individual modules within a [`Detector`](@ref) instance.

The `.modules` field is a dictionary which maps the modules to their module IDs:

```@example 1
det.modules
```

To access a module with a given module ID, one can either use this dictionary or
index the [`Detector`](@ref) directly

```@example 1
detector_module = det[808976933]
```