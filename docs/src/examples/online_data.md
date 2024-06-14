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

and the online tree holds 3 events and 3 summaryslices:

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
    also contains summaryslices and timeslices (timeslices are not implemented yet).
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
event = getevent(f.offline, 127, 2)
```

!!! note

    Events in a ROOT tree are not strictly ordered by time or `frame_index` and
    `trigger_counter`, therefore accessing an event via these two parameters needs a
    traverse through the tree. The indices are cached for future access but you may
    experience some delays especially dependening on the location of the event in
    the tree. In future, a fuzzy binary search might be implemented to speed up this
    process signifficantly.
