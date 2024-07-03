# Orientations

The following example shows how to read orientations from a calibration output
(ROOT file) and plot the yaw, pitch and roll values for an optical module.

The data used in this example is provided by [KM3NeTTestData.jl](https://git.km3net.de/km3py/km3net-testdata).

```@example 1
using KM3io
using KM3NeTTestData
using CairoMakie
using Dates
```

We use [`Makie`](https://makie.org) for plotting:
```@example 1
fig = Figure(size=(900, 400), fontsize=16)
ax_yaw =  Axis(fig[1, 1])
ax_pitch_and_roll =  Axis(fig[1, 2])
```

We load the orientations data and extract the quaternions including the corresponding times from it:

```@example 1
o = read(datapath("calib", "KM3NeT_00000049_0.0.0_00007631_00007676_1.orientations.root"), Orientations)
qdata = o(808972593)
```

The times are converted to `DateTime` objects, which Makie will understand and
display them in a human readable way.

```@example 1
times = unix2datetime.(qdata.t)
```

We convert the [`Quaternion`](@ref)s to [`Compass`](@ref)es to be able to access
the yaw, pitch and roll values.

```@example 1
compasses = Compass.(qdata.q)
yaws = [c.yaw for c in compasses]
pitches = [c.pitch for c in compasses]
rolls = [c.roll for c in compasses]
```

...and we populate the plots:

```@example 1
scatter!(ax_yaw, times, yaws, label="yaw")
axislegend(ax_yaw, position = :rb)

scatter!(ax_pitch_and_roll, times, pitches, label="pitch")
scatter!(ax_pitch_and_roll, times, rolls, label="roll")
axislegend(ax_pitch_and_roll, position = :rt)

fig
```
