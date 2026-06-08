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

## Comparing Detectors, Modules and PMTs

Two objects of the same type can be compared structurally with
[`compare`](@ref), which returns a [`Diff`](@ref) tree describing every
difference. The comparison is recursive: it descends from a [`Detector`](@ref)
into its [`DetectorModule`](@ref)s and further down to the individual
[`PMT`](@ref)s, following the same iteration that powers `for m in det` and
`for pmt in m`. Elements are matched by their identity (module ID, PMT channel
ID), so the result does not depend on the order in which modules or PMTs are
stored.

```@example compare
using KM3io, KM3NeTTestData

det = Detector(datapath("detx", "KM3NeT_00000133_20221025.detx"))
```

Comparing an object with itself yields an empty diff:

```@example compare
compare(det, det)
```

Let's introduce a couple of differences. We pick an optical module, shift the
``z``-coordinate of its first PMT by 5 cm and change the module time offset
``t_0`` by 3 ns:

```@example compare
m = first(m for m in det if isopticalmodule(m))

shifted_pmts = copy(m.pmts)
p = shifted_pmts[1]
shifted_pmts[1] = PMT(p.id, p.pos + Position(0.0, 0.0, 0.05), p.dir, p.t₀, p.status)

m_modified = DetectorModule(m.id, m.pos, m.location, m.n_pmts, shifted_pmts, m.q, m.status, m.t₀ + 3.0)

d = compare(m, m_modified)
```

The printed tree shows the module time offset change and, nested below the
affected PMT, the position change together with its magnitude. The diff is also
a value you can inspect programmatically:

```@example compare
isidentical(d)
```

```@example compare
ndiffs(d)
```

```@example compare
d.changes
```

Elements which exist on only one side are reported separately. Here we compare
the module against a copy with its first PMT removed:

```@example compare
m_fewer = DetectorModule(m.id, m.pos, m.location, Int8(m.n_pmts - 1), m.pmts[2:end], m.q, m.status, m.t₀)
compare(m, m_fewer)
```

### Comparing two calibrations with a tolerance

A common use case is to check whether two descriptions of the *same* detector
agree, for example a `DETX` (ASCII) and a `DATX` (binary) export, or the output
of two calibration tools. Floating point fields (positions, time offsets,
quaternions, PMT directions) are compared with `isapprox`, and the tolerance can
be set via the `atol` and `rtol` keywords.

```@example compare
datx = Detector(datapath("datx", "KM3NeT_00000133_20221025.datx"))

ndiffs(compare(det, datx))
```

At full precision a number of PMT directions differ, because the `DETX` stores
them with fewer digits than the binary `DATX`. Allowing an absolute tolerance of
``10^{-5}`` makes the two descriptions compare equal:

```@example compare
isidentical(compare(det, datx; atol=1e-5))
```

By default `NaN` values at the same position are treated as equal (configurable
with the `nanequal` keyword), so partially uncalibrated detectors can be compared
without every `NaN` field showing up as a difference.

### Comparing other types

[`compare`](@ref) is generic: any struct that is not a registered container (see
[`difftrait`](@ref)) is compared field by field via `fieldnames`, so it also
works on offline events, tracks, hits and your own types. The leaf/container
boundary and the element matching key can be customised by adding methods to
[`difftrait`](@ref) and [`diffkey`](@ref).
