# HDF5

Plain ASCII (CSV) files are often perfectly fine for small, tabular datasets but
when dealing with larger amounts of data, HDF5 comes in handy with compression,
metadata and hierachical datasets. KM3NeT uses HDF5 in many analysis chains,
often to store intermediate or end results.

This example shows how to create an HDF5 file and write some vectors of structs
into different datasets.

```@example 1
using KM3io
using Random

Random.seed!(23)  # to make things reproducible ;)

f = H5File("foo.h5", "w")
```

We now have an `H5File` instance which we can use to store datasets.

Let's say we have our custom data type (`struct`) like

```@example 1
struct Particle
    x::Float32
    y::Float32
    E::Int64
end
```

and we generate instances of `Particle` in a loop which we want to dump directly
into an HDF5 file to the dataset stored at `simulation/particles`, meaning that
`simulation` is the group name and `particles` the dataset name.

## Creating datasets

First, we create our dataset with our type `Particle`. This is a so called
`H5CompoundDataset` and resembles a dataset wich has a compound type (`struct`)
associated with it:

```@example 1
dset = create_dataset(f, "simulation/particles", Particle)
```

We fill some random particles using the dummy loop:

```@example 1
for i in 1:1000
    # creates some random particle
    particle = Particle(rand(), rand(), rand(1:1000))
    # we push to the dataset, just like if it was an Array
    push!(dset, particle)
end
```

!!! note

    To avoid excessive I/O, KM3io uses a cache for each `H5CompoundDataset`. If you
    don't close the `H5File` properly, you might lose data which is still sitting in
    the cache. Therefore, always use `close(f)` to make sure that all the caches are
    dumped to the HDF5 file. The methods `flush(d::H5CompoundDataset)` and
    `flush(f::H5File)` can be used to manually to prematurely flush the cache of a
    dataset or all caches of an HDF5 file respectively.

Let's close the file

```@example 1
close(f)
```

## Reading datasets

We open the file from the previous example with `HDF5.jl`, just to demonstrate
that we can read it without any `KM3NeT` related libraries:

```@example 1
using HDF5

f = h5open("foo.h5")
particles = f["simulation/particles"]

@show particles[1:5]
```

Notice that `HDF5.jl` automatically created `NamedTuple` instances with the same
fieldnames as our own `struct` definition of `Particle`. This means that the
elements behave just like the original one regarding the field access:

```@example 1
particles[2].E
```

The whole vector can also be reinterpreted to the original `struct` definition
with zero-cost. This can be mandatory if the data is then passed to other
methods which require a specific type (in this case `Particle`). The following
line will only work if `Particle` is already defined (i.e. the correspoinding
module has been loaded). It is also mandatory to pass a slice (here, we pass the
full slice by using `[:]`) to `reinterpret` and not the dataset itself:

```@example 1
reinterpreted_particles = reinterpret(Particle, particles[:])
```

Each element is now a proper `Particle` instance:

```@example 1
reinterpreted_particles[4]
```

`KM3io` also writes the name of the `struct` into the attributes of the dataset:

```@example 1
attrs(particles)["struct_name"]
```

## Adding metadata

Sometimes it's useful to keep track of additional metadata, e.g. a given set of
parameters for a specific dataset. The `addmeta()` function can be used to
attach key-value-pairs from a struct to a variety of HDF5 structures, like
files, datasets or groups.
The following example demonstrates it:

```@example 2
using KM3io
using HDF5

struct SimulationParameters
    can_height::Int32
    can_radius::Int32
    minimum_energy::Float64
    maximum_energy::Float64
end

simparams = SimulationParameters(800, 200, 1e3, 1e7)

f = h5open("simulation.h5", "w")
addmeta(f, simparams)

attributes(f)
```

To access individual attributes, use `HDF5.read_attribute`:

```@example 2
read_attribute(f, "can_radius")
```


!!! note

    It is possible to add metadata to datasets and groups too. Make sure that the
    struct you pass to `addmeta()` only contains primitive types or strings in
    their fields. Arrays and other nested or compound fieldtypes are not supported by HDF5.
