# ROOT Files

The two main types of ROOT files in KM3NeT are the online and offline files,
however, both types can be mixed together as the data is stored in distinct ROOT
trees. `UnROOT` has a single `ROOTFile` type to represent a KM3NeT ROOT file
which can be used to access both the online and offline information. This
section describes what kind of data is stored in each tree and how to access them.

## Inspecting file contents

A KM3NeT ROOT file may contain offline events, online events, summaryslices,
timeslices, or any combination of those, for example, an offline DST file can
carry the summaryslices of the underlying run alongside its reconstructed
events. A handful of predicates make it easy to check what is actually present
without poking into the lazy containers:

- [`hasofflineevents`](@ref) === `true` if the file has a non-empty offline event tree (`E`).
- [`hasonlineevents`](@ref) === `true` if the file has a non-empty online event tree (`KM3NET_EVENT`).
- [`hassummaryslices`](@ref)  === `true` if the file has a non-empty summaryslice tree (`KM3NET_SUMMARYSLICE`).
- [`hastimeslices`](@ref)  === `true` if the file has any non-empty timeslice tree; pass a stream symbol (`:L0`, `:L1`, `:L2`, `:SN` or `:TS`) to check a specific one. The per-stream shortcuts [`hasl0timeslices`](@ref), [`hasl1timeslices`](@ref), [`hasl2timeslices`](@ref) and [`hassntimeslices`](@ref) are also available.

Each returns `false` when the corresponding tree is missing or empty, so they
are safe to call on any file:

```julia-repl
julia> using KM3io

julia> f = ROOTFile("KM3NeT_00000133_00015285.offline.dst.root");

julia> hasofflineevents(f), hasonlineevents(f), hassummaryslices(f)
(true, false, true)
```

When `hasonlineevents(f)` is `false` but `hassummaryslices(f)` is `true`, the
file still has an `OnlineTree`, but `f.online.events` will be `nothing` and
should not be accessed without a guard. The same applies to
`f.online.summaryslices` and `f.online.timeslices.<stream>` in the reverse cases.

## File meta data

Every application of the [`Jpp`](https://git.km3net.de/common/jpp) processing
chain stamps the ROOT file with a bit of provenance (the application name, its
`GIT` release, the ROOT version, the full command line and the host system) via
the `JMeta` mechanism of `km3net-dataformat`. `KM3io` reads all of these entries
and exposes them through the `.meta` field of a `ROOTFile` as a
`Vector{`[`MetaData`](@ref)`}`, ordered by processing step: the first entry is
the application which created the file, the last one the application which
touched it most recently. Files without any meta data return an empty vector.

```julia-repl
julia> using KM3io, KM3NeTTestData

julia> f = ROOTFile(datapath("offline", "mcv6.0.gsg_muon_highE-CC_50-500GeV.km3sim.jterbr00008357.jorcarec.aanet.905.root"));

julia> f.meta
8-element Vector{MetaData}:
 MetaData(JConvertEvt @ 14.1.0)
 MetaData(JMuonEnergy @ 14.1.0)
 MetaData(JMuonStart @ 14.1.0)
 MetaData(JMuonGandalf @ 14.1.0)
 MetaData(JMuonStart @ 14.1.0)
 MetaData(JMuonSimplex @ 14.1.0)
 MetaData(JMuonPrefit @ 14.1.0)
 MetaData(JTriggerEfficiency @ 14.1.0)
```

Each [`MetaData`](@ref) exposes the well-known entries as fields
(`application`, `datetime`, `revision`, `root`, `namespace`, `command`, `system`):

```julia-repl
julia> f.meta[1]
MetaData (JConvertEvt)
  datetime:  2021-04-14T10:36:23
  revision:  14.1.0
  ROOT:      6.22/06
  namespace: KM3NET
  hostname:  ccwsge0526
  system:    Linux ccwsge0526 3.10.0-1160.6.1.el7.x86_64 #1 SMP Tue Nov 17 13:59:11 UTC 2020 x86_64
  command:   /Jpp/out//Linux/bin//JConvertEvt -f ... -d 2 --!

julia> f.meta[1].application
"JConvertEvt"

julia> f.meta[1].revision
"14.1.0"

julia> f.meta[1].datetime
2021-04-14T10:36:23
```

The `revision` field returns the `GIT` release, falling back to `SVN` for legacy
files which predate the switch to git.

The `datetime` is the write time of the underlying ROOT key, i.e. the local time
of the machine which wrote the entry (no timezone is stored), and it is `missing`
if the file holds no valid timestamp. Because each application copies the meta
data of its input file into its own output, all entries of a file normally carry
the timestamp of the processing step which produced that file, rather than the
time at which each individual application originally ran.

### The `system` entry

The `system` entry is the `uname` output of the machine which ran the application.
It is decomposed into `sysname`, `hostname`, `kernel_release`, `kernel_datetime`
and `machine`:

```julia-repl
julia> f.meta[1].hostname
"ccwsge0526"

julia> f.meta[1].kernel_release
"3.10.0-1160.6.1.el7.x86_64"

julia> f.meta[1].machine
"x86_64"

julia> f.meta[1].kernel_datetime
2020-11-17T13:59:11
```

!!! warning "kernel_datetime is not a processing time"

    The date embedded in the `system` string is the build time of the operating
    system kernel, taken from the `uname` version field. It is a property of the
    machine, not of the processing step: every job running on the same kernel
    reports the very same value, and it can predate the file by years. Use
    `datetime` to find out when a file was actually produced.

The raw key-value pairs exactly as stored in the file are reachable by indexing,
along with `keys`, `haskey` and `get`:

```julia-repl
julia> f.meta[1]["GIT"]
"14.1.0"

julia> keys(f.meta[1])
KeySet for a Dict{String, String} with 6 entries. Keys:
  "system"
  "command"
  "namespace"
  "ROOT"
  "GIT"
  "application"
```

To dump the whole processing chain in a readable form, use [`printmeta`](@ref),
which accepts a `ROOTFile`, a `Vector{MetaData}` or a single [`MetaData`](@ref)
and optionally an `IO` as its first argument:

```julia-repl
julia> printmeta(f)
Meta data (8 processing steps, oldest first)

[1] JConvertEvt
    datetime:  2021-04-14T10:36:23
    revision:  14.1.0
    ROOT:      6.22/06
    namespace: KM3NET
    system:    Linux ccwsge0526 3.10.0-1160.6.1.el7.x86_64 #1 SMP Tue Nov 17 13:59:11 UTC 2020 x86_64
    command:   /Jpp/out//Linux/bin//JConvertEvt -f ... -d 2 --!

[2] JMuonEnergy
    datetime:  2021-04-14T10:36:23
    revision:  14.1.0
    ...
```

!!! note

    The meta data is auxiliary information which is read eagerly when the file is
    opened. If a file carries a corrupted `META` directory, a warning is emitted
    and `f.meta` is empty, but the file itself stays readable.

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

julia> for event in eachevent(f.offline)
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

!!! tip "Prefer eachevent"

    [`eachevent`](@ref) is the recommended way to iterate an offline tree. On top
    of a plain `for event in eachevent(f.offline)` loop, it lets you skip whole
    sub-collections you do not need via the `skip` keyword, for example
    `eachevent(f.offline; skip=(:hits, :mc_hits, :trks))`, or name the ones to
    keep with `only`, e.g. `eachevent(f.offline; only=:mc_trks)`. Skipped
    collections are returned as empty vectors and their (usually dominant) ROOT
    baskets are never read from disk, which speeds up the iteration a lot when only
    part of each event is needed. The branches are `:hits`, `:mc_hits`, `:trks` and
    `:mc_trks`.

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

for entry in tape
    @show entry
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

julia> for event ∈ eachevent(f.online)
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

### Timeslices

Timeslices are the raw hit data from which summaryslices are derived. Like a
summaryslice, a timeslice spans 100 ms, but instead of a single rate byte per PMT
it keeps **every individual hit**, grouped per optical module into
[`SuperFrame`](@ref)s. The DAQ writes them in up to five streams: four physics
streams, ordered by the applied coincidence level, and the bare stream:

| Stream | Field | Content |
|:-------|:------|:--------|
| L0 | `.L0` | unfiltered, all hits (only stored for short, dedicated runs) |
| L1 | `.L1` | hits with a loose local coincidence (e.g. on the same module within a few ns) |
| L2 | `.L2` | L1 plus an angular/causality condition (a subset of L1) |
| SN | `.SN` | the supernova stream (higher-order coincidences) |
| TS | `.TS` | the super frames which the data filter discarded, see [Discarded frames](@ref) |

They are reachable through the `.timeslices` field of the `OnlineTree`. Each
present stream is a lazy [`TimesliceContainer`](@ref) and absent (or empty)
streams are `nothing`:

```@example timeslices
using KM3io, KM3NeTTestData

f = ROOTFile(datapath("online", "km3net_online.root"))
f.online.timeslices
```

A single timeslice is read on demand by indexing into a stream; it carries a
header and the super frames:

```@example timeslices
ts = f.online.timeslices.L1[1]
```

```@example timeslices
ts.header
```

Each [`SuperFrame`](@ref) holds the DAQ status words and all the hits recorded by
one optical module during the slice:

```@example timeslices
frame = ts.frames[1]
```

The hits are lightweight [`TimesliceHit`](@ref)s, holding the PMT channel, the
hit time and the time-over-threshold. The module id is stored once on the super
frame rather than on every hit:

```@example timeslices
frame.hits[1:5]
```

To calibrate, hand the whole super frame (which carries the module id) to
[`calibratetime`](@ref), or to [`calibrate`](@ref) for the full geometry
calibration:

```@example timeslices
det = Detector(datapath("detx", "km3net_offline.detx"))
calibratetime(det, frame)[1:5]
```

Containers support indexing, slicing and iteration. A sum over all hits of a
stream is most efficient when written behind a function barrier (`total_hits`
below), so that Julia can specialise on the concrete container type:

```@example timeslices
total_hits(c) = sum(length(frame.hits) for ts in c for frame in ts.frames)
total_hits(f.online.timeslices.L1)
```

The supernova stream is accessed in exactly the same way. Because it only keeps
higher-order coincidences, many of its super frames (and occasionally whole
timeslices) are empty:

```@example timeslices
sn = f.online.timeslices.SN[1]
(nframes = length(sn.frames), nhits = sum(length(fr.hits) for fr in sn.frames; init=0))
```

In addition to the multi-stream `km3net_online.root` used above, the test data
also ships dedicated single-stream samples such as
`KM3NeT_00000267_00025291_L1.root` and `KM3NeT_00000267_00025291_SN.root`, read
the very same way.

!!! note

    Depending on the ROOT split level a file was written with, the super frames
    are stored either as a single member-wise streamed branch (modern files) or
    fully split into one sub-branch per data member (older files); the
    `timeslice_start` time is likewise either a single object leaf or two scalar
    leaves. `KM3io` detects and reads all of these transparently, so the access
    shown above is identical in every case.

### Discarded frames

The `TS` stream is the bare `KM3NET_TIMESLICE` tree, which has no coincidence
level. In a run file it holds the super frames which the data filter **rejected**:
before a frame enters any of the L0, L1, L2 or SN streams, its raw data is checked
for defects, and a frame which fails that check is discarded and dumped here
instead. The stream is therefore complementary to the other four (a discarded
frame appears in none of them) and it is **not physics data**. Historically, before
the L0 stream existed, the same tree was used for the unfiltered hits, and the
`JCLB` application writes raw CLB data into it as well, so a bare timeslice is not
necessarily a discarded one.

It is read like any other stream:

```@example timeslices
ts = f.online.timeslices.TS[1]
```

[`checksum`](@ref) applies the very same check as the data filter and tells why a
frame was thrown out, and `isvalid` is the shortcut for "no defects":

```@example timeslices
frame = ts.frames[1]
(errors = checksum(frame), valid = isvalid(frame))
```

Here the hit times of a PMT are not monotonically increasing ([`TIME_ERROR`](@ref
DAQFrameError)), so the frame was dumped. The other defects are an out-of-range
PMT channel ([`PMT_ERROR`](@ref DAQFrameError)), a hit time beyond the duration of
the frame ([`TDC_ERROR`](@ref DAQFrameError)) and an incomplete UDP transfer
([`UDP_ERROR`](@ref DAQFrameError)), the latter being what
[`testdaqstatus`](@ref) reports. Which defects actually occur in a file depends on
the data filter configuration of the run.

A super frame carries the same DAQ status words as a summary frame, so the status
tools work on both:

```@example timeslices
(hrv = hrvstatus(frame), fifo = fifostatus(frame), active = count_active_channels(frame))
```


## [DST Format](@id dst_format)

A DST ("Data Summary Tree") is a compact summary of MC truth, hits, and
reconstruction results produced from offline files. KM3NeT DST files
typically contain:

- An `E` tree identical to the offline event format. It is parsed by
  `OfflineTree` and reachable via the `.offline` field of `ROOTFile`,
  exactly like a regular offline file.
- A `T` tree with one entry per event, holding several summary structs
  (e.g. `MC_evts_summary`, `MC_trks_summary`, `hits_summary`,
  `cascade_summary`, `crkv_hits`, per-algorithm `rec_trks_summary`, BDT
  scores). This tree is exposed as a [`DSTTree`](@ref) via the `.dst`
  field of `ROOTFile`.
- An optional `headerTree` carrying per-source-file metadata when
  multiple input files have been merged into one DST: the original
  `Head`, the run number and the live time. Parsed into a
  [`DSTRunHeaders`](@ref).
- An optional `dst_history` directory recording the input files and the
  command line that produced the DST. Parsed into a [`DSTHistory`](@ref).
- An optional `HeadDir` directory: an alternative on-disk encoding of
  the global header as a `TDirectory` of `TNamed` entries (one per
  header field, with the field name in `fName` and the value in
  `fTitle`). Parsed into the same `MCHeader` type as the regular
  `Head` object and exposed via the `.head_dir` property. The `Head`
  object and the `HeadDir` directory are independent; a file can carry
  one, the other, both, or neither.

### Schema-flexible access

The DST schema varies between productions: not every branch is
guaranteed to be present, and additional branches may appear.
`DSTTree` discovers the top-level branches of the `T` tree at load
time and exposes them dynamically as properties on each
[`DSTEvent`](@ref). For composite branches (multiple leaves), the
property returns a [`DSTBranchView`](@ref), a lazy NamedTuple-like view
onto the underlying leaves. For a single scalar branch, the property
returns the value directly.

```julia-repl
julia> using KM3io, KM3NeTTestData

julia> f = ROOTFile(datapath("dst", "mcv6.gsg_numu-CCHEDIS_1e2-1e8GeV.sirene.jte.jchain.aashower.dst.bdt_trk.bdt_casc.10events.root"))
ROOTFile{OfflineTree (10 events), DSTTree (10 events, 10 branches)}

julia> f.dst
DSTTree (10 events, 10 branches)

julia> f.dst[1]
DSTEvent (idx=1, 10 branches)

julia> propertynames(f.dst[1])
(:bdt_casc, :bdt_trk, :crkv_hits, :sum_casc, :sum_hits, :sum_jpptrack, :sum_mc_evt, :sum_mc_hits, :sum_mc_trks, :sum_trig_hits)

julia> f.dst[1].sum_mc_evt
DSTBranchView(E_max_gen, E_min_gen, MC_run, livetime_DAQ, livetime_sim, n_gen, weight, weight_noOsc)

julia> f.dst[1].sum_mc_evt.weight
1.1701346f-5

julia> f.dst[1].sum_mc_evt.MC_run
41

julia> f.dst[1].bdt_trk
2-element Vector{Float32}:
  1.0
 -2.0
```

The `sum_mc_trks` branch carries a flattened version of the
highest-energy MC muon ("tmuon") in addition to the count and energy
totals. Its leaves are exposed under the `tmuon_` prefix:

```julia-repl
julia> v = f.dst[1].sum_mc_trks
DSTBranchView(Emax, Etot, Evis, ntrks, tmuon_AAObject_tmuon_TObject_tmuon_fBits, tmuon_AAObject_tmuon_TObject_tmuon_fUniqueID, tmuon_AAObject_tmuon_any, tmuon_AAObject_tmuon_usr, tmuon_AAObject_tmuon_usr_names, tmuon_E, tmuon_comment, tmuon_counter, tmuon_dir_x, tmuon_dir_y, tmuon_dir_z, tmuon_error_matrix, tmuon_fitinf, tmuon_hit_ids, tmuon_id, tmuon_len, tmuon_lik, tmuon_mother_id, tmuon_pos_x, tmuon_pos_y, tmuon_pos_z, tmuon_rec_stages, tmuon_rec_type, tmuon_status, tmuon_t, tmuon_type)

julia> v.ntrks, v.Etot, v.Emax, v.Evis
(42, 31144.157509773937, 31144.157509773937, 31144.157509773937)

julia> v.tmuon_E, v.tmuon_pos_x, v.tmuon_dir_z
(31144.157509773937, -410.1658000858246, -0.29218912046986895)
```

Similarly, `crkv_hits` exposes its eight per-shell members directly:

```julia-repl
julia> v = f.dst[1].crkv_hits
DSTBranchView(closest, furthest, nhits, nhits_100m, nhits_200m, nhits_20m, nhits_50m, sumtot)

julia> v.nhits
6-element Vector{Int32}:
   5
 147
   1
  20
   1
  47
```

### Iteration and slicing

`DSTTree` implements the array protocol (`length`, indexing, slicing,
iteration):

```julia-repl
julia> length(f.dst)
10

julia> [e.sum_mc_evt.weight for e in f.dst]
10-element Vector{Float32}:
 1.1701346f-5
 0.0060263677
 8.647894f-5
 0.016838863
 0.22624199
 9.984811f-6
 0.030309035
 0.0013151936
 2.4152963f-5
 0.08190833
```

Raw branch access is available by passing the path within the `T`
tree:

```julia-repl
julia> f.dst["sum_mc_evt/weight", :]
10-element Vector{Float32}:
 1.1701346f-5
 0.0060263677
 ...
```

### Branch name registry

The constant [`DST_BRANCHES`](@ref) and the helper
[`describe_dst_branch`](@ref) provide a lookup table of well-known
top-level branch names with one-line descriptions. They are purely a
discoverability aid; `DSTTree` exposes whatever branches the file
actually contains, regardless of whether they appear in the registry.

```julia-repl
julia> describe_dst_branch("sum_casc")
"Cascade reconstruction summary (cascade_summary): aashower hit/total counts in time windows, inertia tensor metrics. Observed in v6 productions; not documented upstream."

julia> describe_dst_branch("not_in_registry")
missing
```

#### Known summary parameters

The table below is generated from [`DST_BRANCHES`](@ref) at doc-build
time. Most descriptions follow the upstream documentation at
<https://common.pages.km3net.de/aanet/dstpage.html>. To register a new
local branch name, push it into `DST_BRANCHES` after `using KM3io`.

```@example dst_branches
using KM3io
using Markdown

io = IOBuffer()
println(io, "| Branch | Description |")
println(io, "|:-------|:------------|")
for k in sort!(collect(keys(DST_BRANCHES)))
    desc = replace(DST_BRANCHES[k], "_" => "\\_")
    println(io, "| `", k, "` | ", desc, " |")
end
Markdown.parse(String(take!(io)))
```

### Headers and provenance

A `DSTTree` exposes four optional header / provenance properties,
each populated only when the corresponding object is present in the
file:

| Property | Source on disk | Type | Fallback |
|:---------|:---------------|:-----|:---------|
| `.header` | `Head` object | `MCHeader` | `missing` |
| `.head_dir` | `HeadDir` `TDirectory` | `MCHeader` | `nothing` |
| `.run_headers` | `headerTree` `TTree` | [`DSTRunHeaders`](@ref) | `nothing` |
| `.history` | `dst_history` `TDirectory` | [`DSTHistory`](@ref) | `nothing` |

`.header` and `.head_dir` carry the same kind of information (a
`Dict{String,String}` of header tags wrapped in `MCHeader`) but read
from two distinct on-disk encodings; in files that carry both, the
contents are typically identical, but no enforcement is done. The
`headerTree` is per-source-file (one row per merged input), whereas
`Head` / `HeadDir` are global to the DST.

```julia-repl
julia> f.dst.run_headers
DSTRunHeaders (1 source files)

julia> f.dst.run_headers.run_numbers
1-element Vector{Int32}:
 1

julia> f.dst.run_headers.livetimes_s
1-element Vector{Float64}:
 3.15576e7

julia> f.dst.run_headers.headers[1]
MCHeader
  ...

julia> f.dst.history
DSTHistory (160 input files)

julia> f.dst.history.input_files[1]
"/sps/km3net/repo/v6_ARCA115/.../mcv6.gsg_numu-CCHEDIS_1e2-1e8GeV.sirene.jte.jchain.aashower.41.root"
```

The `.head_dir` property behaves like `.header`: every header field is
addressable by its name, with structured ones (e.g. `fixedcan`,
`spectrum`, `DAQ`) returning `NamedTuple`s as defined by the MC
header registry.

```julia-repl
julia> f.dst.head_dir
MCHeader
  DAQ => (livetime = 10741,)
  calibration => dynamical
  depth => 3450
  detector => Any["JSirene", "00000133/.../KM3NeT_..._offline.detx"]
  ...

julia> f.dst.head_dir.start_run
15285

julia> f.dst.head_dir.fixedcan
(xcenter = 25.3, ycenter = 295, zmin = 0, zmax = 1039.7, radius = 624.7)
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
