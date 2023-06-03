# ROOT Files

The two main types of ROOT files in KM3NeT are the online and offline files,
however, both types can be mixed together as the data is stored in distinct ROOT
trees. `UnROOT` has a single `ROOTFile` type to represent a KM3NeT ROOT file
which can be used to access both the online and offline information. This
section describes what kind of data is stored in each tree and how to access them.

## [Offline Dataformat](@id offline dataformat)

The [offline
dataformat](https://git.km3net.de/common/km3net-dataformat/-/tree/master/offline)
is used to store Monte Carlo (MC) simulations and reconstruction results. The
`OfflineTree` type represents an actual offline file and it is essentially a
vector of events (`Vector{Evt}`) with some fancy caching, lazy access and
slicing magic. The offline tree is accessible via the `.offline` field of the
`ROOTFile` type.

### MC Header

The MC header stores metadata related to the simulation chain. The individual entries
can be accessed as properties, as shown below.

``` julia-repl
julia> using KM3io, KM3NeTTestData

julia> f = ROOTFile(datapath("offline", "numucc.root"))
ROOTFile{OnlineTree (0 events, 0 summaryslices), OfflineTree (10 events)}

julia> f.offline
OfflineTree (10 events)

julia> f.offline.header
MCHeader
  DAQ => (livetime = 394,)
  PDF => (i1 = 4, i2 = 58)
  XSecFile => Any[]
  can => (zmin = 0, zmax = 1027, r = 888.4)
  can_user => [0.0, 1027.0, 888.4]
  coord_origin => (x = 0, y = 0, z = 0)
  cut_in => (Emin = 0, Emax = 0, cosTmin = 0, cosTmax = 0)
  cut_nu => (Emin = 100, Emax = 1.0e8, cosTmin = -1, cosTmax = 1)
  cut_primary => (Emin = 0, Emax = 0, cosTmin = 0, cosTmax = 0)
  cut_seamuon => (Emin = 0, Emax = 0, cosTmin = 0, cosTmax = 0)
  decay => ["doesnt", "happen"]
  detector => NOT
  drawing => Volume
  end_event => Any[]
  genhencut => (gDir = 2000, Emin = 0)
  genvol => (zmin = 0, zmax = 1027, r = 888.4, volume = 2.649e9, numberOfEvents = 100000)
  kcut => 2
  livetime => (numberOfSeconds = 0, errorOfSeconds = 0)
  model => (interaction = 1, muon = 2, scattering = 0, numberOfEnergyBins = 1, field_4 = 12)
  muon_desc_file => Any[]
  ngen => 100000.0
  norma => (primaryFlux = 0, numberOfPrimaries = 0)
  nuflux => Real[0, 3, 0, 0.5, 0.0, 1.0, 3.0]
  physics => (program = "GENHEN", version = "7.2-220514", date = 181116, time = 1138)
  seed => (program = "GENHEN", level = 3, iseed = 305765867, field_3 = 0, field_4 = 0)
  simul => (program = "JSirene", version = 11012, date = "11/17/18", time = 7)
  sourcemode => diffuse
  spectrum => (alpha = -1.4,)
  start_run => 1
  target => isoscalar
  usedetfile => false
  xlat_user => 0.63297
  xparam => OFF
  zed_user => [0.0, 3450.0]


julia> f.offline.header.genvol
(zmin = 0, zmax = 1027, r = 888.4, volume = 2.649e9, numberOfEvents = 100000)

julia> f.offline.header.genvol.volume
2.649e9
```

### Event data

The following REPL session shows how to open a file, access individual events or
slices of events, loop through events and access e.g. the tracks which are
stored in the events.

``` julia-repl
julia> using KM3io, KM3NeTTestData

julia> f = ROOTFile(datapath("offline", "km3net_offline.root"))
ROOTFile{OfflineTree (10 events)}

julia> f.offline[5]
KM3io.Evt (83 hits, 0 MC hits, 56 tracks, 0 MC tracks)

julia> f.offline[3:5]
3-element Vector{KM3io.Evt}:
 KM3io.Evt (318 hits, 0 MC hits, 56 tracks, 0 MC tracks)
 KM3io.Evt (157 hits, 0 MC hits, 56 tracks, 0 MC tracks)
 KM3io.Evt (83 hits, 0 MC hits, 56 tracks, 0 MC tracks)

julia> event = f.offline[1]
KM3io.Evt (176 hits, 0 MC hits, 56 tracks, 0 MC tracks)

julia> event.trks[1:4]
4-element Vector{KM3io.Trk}:
 KM3io.Trk(1, [445.835395997812, ... , 294.6407542676734, 4000)
 KM3io.Trk(2, [445.835395997812, ... , 294.6407542676734, 4000)
 KM3io.Trk(3, [448.136188112227, ... , 294.6407542676734, 4000)
 KM3io.Trk(4, [448.258348900570, ... , 291.64653112688273, 4000)

julia> for event in f.offline
           @show event
       end
event = KM3io.Evt (176 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (125 hits, 0 MC hits, 55 tracks, 0 MC tracks)
event = KM3io.Evt (318 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (157 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (83 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (60 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (71 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (84 hits, 0 MC hits, 56 tracks, 0 MC tracks)
event = KM3io.Evt (255 hits, 0 MC hits, 54 tracks, 0 MC tracks)
event = KM3io.Evt (105 hits, 0 MC hits, 56 tracks, 0 MC tracks)
```

## [Online Dataformat](@id online_dataformat)

The [online
dataformat](https://git.km3net.de/common/km3net-dataformat/-/tree/master/online)
refers to the dataformat which is written by the data acquisition system (DAQ)
of the KM3NeT detectors, more precisely, the ROOT files produced by the
`JDataFilter` which is part of the [`Jpp`](https://git.km3net.de/common/jpp)
framework. The very same format is used in run-by-run (RBR) Monte Carlo (MC)
productions, which mimic the detector response and therefore produce similarly
structured data. The online data can be accessed via the `.online` field of the
`ROOTFile` type.

### Event data

The events are accessible via `ROOTFile(filename).online.events` which supports
indexing, slicing and iteration, just like the we have seen above, in case of
the offline events. Notice however that the online format also contains other
types of trees, that's why the explicit `.events` field is needed. Everything is
lazily loaded so that the data is only occupying memory when it's actually
accessed, similar to the offline access. In the examples below, we use
**[`KM3NeTTestdata`](https://git.km3net.de/km3py/km3net-testdata)** to get
access to small sample files.

``` julia
julia> using KM3io

julia> using KM3NeTTestData

julia> f = ROOTFile(datapath("online", "km3net_online.root"))
ROOTFile{OnlineTree (3 events, 3 summaryslices), OfflineTree (0 events)}

julia> event = f.online.events[1]
KM3io.DAQEvent with 96 snapshot and 18 triggered hits

julia> event.triggered_hits[4:8]
5-element Vector{KM3io.TriggeredHit}:
 KM3io.TriggeredHit(808447186, 0x00, 30733214, 0x19, 0x0000000000000016)
 KM3io.TriggeredHit(808447186, 0x01, 30733214, 0x15, 0x0000000000000016)
 KM3io.TriggeredHit(808447186, 0x02, 30733215, 0x15, 0x0000000000000016)
 KM3io.TriggeredHit(808447186, 0x03, 30733214, 0x1c, 0x0000000000000016)
 KM3io.TriggeredHit(808451907, 0x07, 30733441, 0x1e, 0x0000000000000004)

julia> for event ∈ f.online.events
           @show event.header.frame_index length(event.snapshot_hits)
       end
event.header.frame_index = 127
length(event.snapshot_hits) = 96
event.header.frame_index = 127
length(event.snapshot_hits) = 124
event.header.frame_index = 129
length(event.snapshot_hits) = 78
```

### Summaryslices and Summary Frames

Summaryslices are generated from timeslices (raw hit data) and are produced by
the DataFilter. A slice contains the data of 100ms and is divided into so-called
frames, each corresponding to the data of a single optical module. Due to the
high amount of data, the storage of timeslices is usually reduced by a factor of
10-100 after the event triggering stage. However, summaryslices are covering the
full data taking period. They however do not contain hit data but only the rates
of the PMTs encoded into a single byte, which therefore is only capable to store
256 different values. The actual rate is calcuated by a helper function (TODO).

The summaryslices are accessible using the `.summaryslices` attribute of the
`OnlineTree` instance, which again is hidden behind the `.online` field of a `ROOTFile`:

``` julia
julia> using KM3io, UnROOT, KM3NeTTestData

julia> f = ROOTFile(datapath("online", "km3net_online.root"))
ROOTFile{OnlineTree (3 events, 3 summaryslices), OfflineTree (0 events)}

julia> f.online.summaryslices
KM3io.SummarysliceContainer with 3 summaryslices

julia> for s ∈ f.online.summaryslices
           @show s.header
       end
s.header = KM3io.SummarysliceHeader(44, 6633, 126, KM3io.UTCExtended(0x5dc6018c, 0x23c34600, false))
s.header = KM3io.SummarysliceHeader(44, 6633, 127, KM3io.UTCExtended(0x5dc6018c, 0x29b92700, false))
s.header = KM3io.SummarysliceHeader(44, 6633, 128, KM3io.UTCExtended(0x5dc6018c, 0x2faf0800, false))
```

To access the actual PMT rates and flags (e.g. for high-rate veto or FIFO
status), the `s.frames` can be used (TODO).


