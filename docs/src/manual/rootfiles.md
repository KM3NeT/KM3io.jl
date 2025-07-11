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

### Multiple Files

The [`OfflineEventTape`](@ref) offers an easy way to iterate over many sources
(can be a mix of filepaths and XRootD URLs). During the iteration, files with an
empty offline tree are automatically skipped.

The following example takes two files from the [KM3NeT
TestData](https://git.km3net.de/common/km3net-testdata) samples and iterate
through both of them in a simple loop.

```@example OfflineEventTape
using KM3io, KM3NeTTestData

tape = KM3io.OfflineEventTape([
    datapath("offline", "numucc.root"),
    datapath("offline", "km3net_offline.root")
])

for event in tape
    @show event
end
```

More examples can be found here: [Offline Event Tape Examples](@ref offline_event_tape)

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
julia> using KM3io, KM3NeTTestData

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
256 different values. The actual rate is calcuated by the helper functions
`pmtrate()` and `pmtrates()` which take a `SummaryFrame` and optionally a PMT
channel ID as arguments.

The summaryslices are accessible using the `.summaryslices` attribute of the
`OnlineTree` instance, which again is hidden behind the `.online` field of a `ROOTFile`:

``` julia
julia> using KM3io, KM3NeTTestData

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

Each summaryslice consists of multiple frames, one for every optical module which
has sent data during the recording time of the corresponding timeslice.

!!! note

    During run transistions, the number of summaryframes in a summaryslice is fluctuating a lot until
    it eventually saturates, usually within a few seconds or minutes. Therefore, it is expected that the
    number of summaryframes (i.e. active DOMs) is low at the beginning of the file and stabilises after
    a few summaryslices.

To access the actual PMT rates and flags (e.g. for high-rate veto or FIFO
status) of a summaryframe, several helper functions exist. Let's grab a summaryslice:

```@example 2
using KM3io, KM3NeTTestData

f = ROOTFile(datapath("online", "km3net_online.root"))

s = f.online.summaryslices[1]
```

and have a look at one of the frames, the 23rd of the first summaryslice:


```@example 2
frame = s.frames[23]
```

The White Rabbit status:

```@example 2
wrstatus(frame)
```

Checking if any of the PMTs is in high rate veto:

```@example 2
hrvstatus(frame)
```

The number of PMTs in high rate veto:

```@example 2
count_hrvstatus(frame)
```

Checking if any of the TDC FIFOs were almost full:

```@example 2
fifostatus(frame)
```

Counting the number of TDCs which had FIFO almost full:

```@example 2
count_fifostatus(frame)
```

The rates of each individual PMT channel ordered by increasing channel ID:

```@example 2
pmtrates(frame)
```

Individual PMT parameters can be accessed as well, by passing the summaryframe and
the PMT ID (DAQ channel ID):

```@example 2
pmtrate(frame, 3)
```

Here is an example of a simple summary output:

```@example 2
for pmt in 0:30
    println("PMT $(pmt): HRV($(hrvstatus(frame, pmt))) FIFO($(fifostatus(frame, pmt)))")
end
```


## xrootd access

You can access files directly via `xrootd` by providing the URL on e.g. HPSS. Be
aware that URL has to be typed correctly, `/` instead of `//` results in an
error!), so it should always start with something like
`root://ccxroot:1999//hpss/...`.

```julia
julia> using KM3io

julia> f = ROOTFile("root://ccxroot:1999//hpss/in2p3.fr/group/km3net/data/raw/sea/KM3NeT_00000132/14/KM3NeT_00000132_00014481.root")
ROOTFile{OnlineTree (136335 events, 107632 summaryslices)}
```

Now you can use it as if it was on your local filesystem. `UnROOT.jl` will take
care of loading only the needed data from the server.

## [Oscillations Open Dataformat](@id oscillations dataformat)

The [oscillations
dataformat](https://git.km3net.de/vcarretero/prepare-opendata-orca6-433kty/-/tree/main?ref_type=heads)
is used to store the responses from a particular oscillations analysis data release. The
`OSCFile` type represents an actual ROOT file and it is essentially a
vector of Response like entries (`Vector{ResponseMatrixBin}`) . Depending on what is stored in the initial ROOT file, neutrinos, data and muons response trees are accessible via the `.osc_opendata_nu`, `.osc_opendata_data` and `.osc_opendata_muons`  fields of the `ROOTFile` type respectively.

### ResponseMatrixBin

The `ResponseMatrixBin` stores individual directions of a bin in order to fill a histogram.

``` julia-repl
julia> using KM3io, KM3NeTTestData

julia> f = OSCFile(datapath("oscillations", "ORCA6_433kt-y_opendata_v0.4_testdata.root"))
OSCFile{OscOpenDataTree of Neutrinos (59301 events), OscOpenDataTree of Data (106 events), OscOpenDataTree of Muons (99 events)}

julia> f.osc_opendata_nu
OscOpenDataTree (59301 events)

julia> f.osc_opendata_nu[1]
KM3io.ResponseMatrixBinNeutrinos(10, 1, 30, 18, -12, 1, 1, 52.25311519561337, 2730.388047646041)

julia> dump(f.osc_opendata_nu[1])
KM3io.ResponseMatrixBinNeutrinos
  E_reco_bin: Int64 10
  Ct_reco_bin: Int64 1
  E_true_bin: Int64 30
  Ct_true_bin: Int64 18
  Flav: Int16 -12
  IsCC: Int16 1
  AnaClass: Int16 1
  W: Float64 52.25311519561337
  Werr: Float64 2730.388047646041

julia> f.osc_opendata_data[1]
KM3io.ResponseMatrixBinData(2, 6, 1, 2.0)

```
