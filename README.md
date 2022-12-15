# KM3io.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://common.pages.km3net.de/KM3io.jl/dev)
[![Build Status](https://git.km3net.de/common/KM3io.jl/badges/main/pipeline.svg)](https://git.km3net.de/common/KM3io.jl/pipelines)
[![Coverage](https://git.km3net.de/common/KM3io.jl/badges/main/coverage.svg)](https://git.km3net.de/common/KM3io.jl/commits/main)

`KM3io.jl` is an pure Julia library which implements I/O functions and utilities
to deal with dataformats used in KM3NeT.

## Installation

`KM3Acoustics.jl` is not an officially registered Julia package but it's
available via the KM3NeT Julia registry. To add the KM3NeT Julia registry,
execute once:

    git clone https://git.km3net.de/common/julia-registry ~/.julia/registries/KM3NeT

Once the registry is added, Julia will make sure to keep it up to date and pick
it whenever you install a package which is registered there.

To install `KM3io.jl`:

    julia> import Pkg; Pkg.add("KM3io")

## Quickstart
