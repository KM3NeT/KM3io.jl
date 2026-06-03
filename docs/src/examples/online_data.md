# Online data

Let's use the `KM3NeTTestData` Julia package which contains all kinds of KM3NeT
related sample files. The `datapath()` function can be used to get a path to
such a file. In the following, we will discover the `numucc.root` file which
contains 10 muon neutrino charged current interaction events.

```@example 1
using KM3io, KM3NeTTestData

f = ROOTFile(datapath("online", "km3net_online.root"))
```

The `ROOTFile` is the container object which gives access to both the online and
offline tree. In this case, the online tree is empty

```@example 1
f.offline
```

and the online tree holds 3 events, 3 summaryslices and the L1 and SN timeslice
streams (3 timeslices each):

```@example 1
f.online
```

## Events

To access a single event, you can use the usual indexing syntax:

```@example 1
some_event = f.online.events[2]
```

!!! note

    While both the offline and online tree contain events which are essentially an
    array of events (`Vector{Evt}` respectively `Vector{DAQEvent}`), the online tree
    also contains summaryslices and timeslices.
    For simplicity, indexing into an `OfflineTree` is directly indexing into events
    by default, while in case of the `OfflineTree` the field `.events` is necessary.

or ranges of events:

```@example 1
events = f.online.events[2:3]
```

Another way to access events is given by getter function `getevent()` (which
also works for online trees). If a single number if passed, it will be treated
as a regular index, just like above:

```@example 1
event = getevent(f.online, 2)
```

when two numbers are passed, the first one is interpreted as `frame_index` and the second one as `trigger_counter`:

```@example 1
event = getevent(f.online, 127, 1)
```

!!! note

    Events in a ROOT tree are not strictly ordered by time or `frame_index` and
    `trigger_counter`, therefore accessing an event via these two parameters needs a
    traverse through the tree. The indices are cached for future access but you may
    experience some delays especially dependening on the location of the event in
    the tree. In future, a fuzzy binary search might be implemented to speed up this
    process signifficantly.

## Timeslices

A timeslice covers the same 100 ms data taking period as a summaryslice but,
instead of a single rate byte per PMT, it keeps every individual hit grouped per
optical module into [`SuperFrame`](@ref)s. KM3NeT stores timeslices in up to four
streams which differ in the applied coincidence level: `L0` (unfiltered), `L1`
and `L2` (loose and tight coincidences) and `SN` (the supernova stream). They are
accessible via `f.online.timeslices`, where each present stream is a lazy
container and absent streams are `nothing`:

```@example 1
f.online.timeslices
```

A single timeslice is read on demand by indexing into a stream:

```@example 1
ts = f.online.timeslices.L1[1]
```

Its header carries the data acquisition meta information:

```@example 1
ts.header
```

The super frames hold the hits per optical module:

```@example 1
frame = ts.frames[1]
```

The hits are lightweight [`TimesliceHit`](@ref)s (PMT channel, time and
time-over-threshold); the module id is stored once on the super frame rather than
on every hit:

```@example 1
frame.hits[1:3]
```

To obtain calibrated hits, pass the whole super frame (which carries the module
id) to [`calibrate`](@ref) or [`calibratetime`](@ref):

```@example 1
det = Detector(datapath("detx", "km3net_offline.detx"))
calibratetime(det, frame)[1:3]
```

Streams support indexing, slicing and iteration. For hot loops, pass the
container into a function (a *function barrier*) so that Julia specialises on its
concrete type:

```@example 1
total_hits(c) = sum(length(frame.hits) for ts in c for frame in ts.frames)
total_hits(f.online.timeslices.L1)
```

The test data also ships dedicated single-stream samples. Here is a real ARCA L1
timeslice file:

```@example 1
f_l1 = ROOTFile(datapath("online", "KM3NeT_00000267_00025291_L1.root"))
ts = f_l1.online.timeslices.L1[1]
(nframes = length(ts.frames), nhits = total_hits(f_l1.online.timeslices.L1))
```

and the corresponding supernova stream, where some timeslices are empty:

```@example 1
f_sn = ROOTFile(datapath("online", "KM3NeT_00000267_00025291_SN.root"))
[length(ts.frames) for ts in f_sn.online.timeslices.SN[1:3]]
```
