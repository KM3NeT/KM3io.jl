# Cherenkov times

In this example, we will pick the best reconstructed muon (from the Jpp muon
reconstruction chain `JMuon`) in each event and calculate the Cherenkov hit time
residuals for each triggered hit.

We open the `numucc.root` file from the `KM3NeTTestData` package:

```@example 1
using KM3io, KM3NeTTestData

f = ROOTFile(datapath("offline", "numucc.root"))
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
m = bestjppmuon(evt)
```

We now use this track as a seed to calculate the Cherenkov photon (see
[`CherenkovPhoton`](@ref)) parameters using [`cherenkov()`](@ref) for each hit
in the event.

```@example 1
cherenkov_photons = cherenkov(m, evt.hits)
```
