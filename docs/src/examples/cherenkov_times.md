# Cherenkov times

In this example, we will pick the best reconstructed muon (from the Jpp muon
reconstruction chain `JMuon`) in each event and calculate the Cherenkov hit time
residuals for each triggered hit.

We open the a sample file from the `KM3NeTTestData` package:

```@example 1
using KM3io, KM3NeTTestData

f = ROOTFile(datapath("offline", "mcv6.0.gsg_muon_highE-CC_50-500GeV.km3sim.jterbr00008357.jorcarec.aanet.905.root"))
```

Each event holds a vector of reconstructed tracks (`Vector{Trk}`) behind the
`.trks` field. This vector contains different stages of reconstruction results
from a variety of reconstruction algorithms (`JMuon`, `JShower`, `aashower`
etc.). `KM3io.jl` exports helper functions to pick the best reconstructed track
for a given reconstruction algorithm. The logic is based on the reference
implementation in [KM3NeT DataFormat
tools](https://git.km3net.de/common/km3net-dataformat/-/blob/master/tools/reconstruction.hh).
The function `bestjppmuon()` can be used to select the best reconstructed `JMuon`
for a given event:

```@example 1
evt = f.offline[1]
best_muon = bestjppmuon(evt)
```

We now use this track as a seed to calculate the Cherenkov photon (see
[`CherenkovPhoton`](@ref)) parameters using [`cherenkov()`](@ref) for each hit
triggered hit in the event. To select only triggered hits, we use the
[`triggered()`](@ref) function together withe `filter()` which returns a new
vector of triggered hits:

```@example 1
cherenkov(best_muon, filter(triggered, evt.hits))
```

To obtain more statistics, we iterate through all the events and calculate the
Cherenkov time residuals for each set of hits based on the best reconstruction
track. We fill the time residuals in a 1D histogram using the
[FHist](https://github.com/Moelf/FHist.jl) package and plot it with
[`Makie`](https://makie.org):

```@example 1
using KM3io, KM3NeTTestData
using FHist
using CairoMakie

f = ROOTFile(datapath("offline", "mcv6.0.gsg_muon_highE-CC_50-500GeV.km3sim.jterbr00008357.jorcarec.aanet.905.root"))
Δts = Hist1D(; counttype=Int, binedges=-10:50)

for evt ∈ eachevent(f.offline)
    m = bestjppmuon(evt)
    cherenkov_photons = cherenkov(m, filter(triggered, evt.hits))
    for cp ∈ cherenkov_photons
        push!(Δts, cp.Δt)
    end
end

fig = Figure(size=(600, 400), fontsize=16)
ax = Axis(fig[1, 1], xlabel="Δt / ns", ylabel="counts")
barplot!(ax, bincenters(Δts), bincounts(Δts))
fig
```
