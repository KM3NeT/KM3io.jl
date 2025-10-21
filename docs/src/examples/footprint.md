# Detector Footprint

The following example shows how to print a detector footprint
using the x and y positions of the base modules.

```@example 1
using KM3io
using KM3NeTTestData
using CairoMakie
```

We use [`Makie`](https://makie.org) for plotting:
```@example 1
fig = Figure(size=(500, 500), fontsize=16)
ax =  Axis(fig[1, 1], xlabel="x / m", ylabel="y / m")
```

We load a detector from the test data:

```@example 1
detector = Detector(datapath("detx", "KM3NeT_00000133_20221025.detx"))
```

Now selecting only the base modules:

```@example 1
bases = filter(isbasemodule, detector)
```

Finally create an array of x and y coordinates and plot the footprint:

```@example 1
xy = [(b.pos.x, b.pos.y) for b in bases]
scatter!(ax, xy)

fig
```
