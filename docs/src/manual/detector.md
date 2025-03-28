# Detector and its Components

In this example, we will explore the components of a KM3NeT detector, which is
represented by the [`Detector`](@ref) type in `KM3io.jl`. The detector
description is stored in so-called
[`DETX` and `DATX` files](https://wiki.km3net.de/index.php/Dataformats#Detector_Description_.28.detx_and_.datx.29),
named after their filename extensions `.detx` (ASCII) and `.datx` (binary) respectively.
By time of writing this example, `v5` is the latest format version.

!!! note

    `KM3io.jl` offers conversions between the different `DETX` format versions.
    Typically, each major version brings a new set of parameters. Downgrading
    is therefore not lossless. When when upgrading from one version to another,
    the new parameters needs to be
    filled in. Some of these can be calculated from existing ones, like
    the module position, which was introduced in `v4` and is equal to the crossing
    point of the PMT axes. Otherwise, these parameters are either set to meaningful
    default values or to `missing`.
    
## Loading a `DETX/DATX` File

The [`Detector`](@ref) type has a constructor which takes a filepath to a
`DETX` or `DATX` file. The
[KM3NeTTestData.jl](https://git.km3net.de/km3py/km3net-testdata) offers a
collection of detector sample files, so let's pick one of them:

```@example 1
using KM3io, KM3NeTTestData

det = Detector(datapath("detx", "detx_v5.detx"))
```

A detector configuration (format version 5) has been loaded with 6 strings
(sometimes also called detection unit or DU) holding a total 114 modules.

## Retrieve a detector from the DB

`KM3io.jl` comes with a `KM3DB.jl` extension which allows to load detector
information directly from the database. The extension is automatically loaded
when `KM3DB` is imported:

```@example KM3DB
using KM3io
using KM3DB

det = Detector(133)
```

Keyword arguments passed as `Detector(det_id; kwarg1=..., kwarg2=..., ...)` are
handed over to the `detx()` function in `KM3DB.jl`.

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

### Detector Modules

Modules have a unique identification number called module ID (sometimes also
called "DOM ID", where DOM stands for "Digital Optical Module") and we can use
this ID to access individual modules within a [`Detector`](@ref) instance.

The `.modules` field is a dictionary which maps the modules to their module IDs:

```@example 1
det.modules
```

A flat vector of modules can be obtained with:

```@example 1
modules(det)
```

To access a module with a given module ID, one can either use the dictionary or
index the [`Detector`](@ref) directly, which is the recommended way:

```@example 1
detector_module = det[808468425]
```

Or for a given string and floor:

```@example 1
det[3, 15]
```

It is possible to select all modules for a given floor on all strings using  the `:` syntax. Here
we select all the base modules on each string:

```@example 1
det[:, 0]
```

Another way is using the `getmodule(d::Detector, string::Integer, floor::Integer)` function
to access a module on a given string and floor:

```@example 1
detector_module = getmodule(det, 3, 15)
```

### PMTs

Each optical module consists of PMTs, which can be access using the `getpmts(m::DetectorModule)` function:

```@example 1
getpmts(detector_module)
```

To access a specific PMT with a given channel ID (TDC ID), use the
`getpmt(m::DetectorModule, channel_id::Integer)` function. Here, we access the
PMT at DAQ channel 0 of our previously obtained detector module:


```@example 1
getpmt(detector_module, 0)
```

#### Rings

PMTs are grouped in horizontal rings, named by letters from `A` to `F`. Ring `A` consists of a single PMT pointing downwards and each of the other five rings hold six PMTs. All the six rings are defined and accessible via

```@example 2
ringA
ringB
ringC
ringD
ringE
ringF
```
