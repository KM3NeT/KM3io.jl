# Examples

## Offline data

Let's use the `KM3NeTTestData` Julia package which contains all kinds of KM3NeT
related sample files. The `datapath()` function can be used to get a path to
such a file. In the following, we will discover the `numucc.root` file which
contains 10 muon neutrino charged current interaction events.

```@example 1
using KM3io, KM3NeTTestData

f = ROOTFile(datapath("offline", "numucc.root"))
```

The `ROOTFile` is the container object which gives access to both the online and
offline tree. In this case, the online tree is empty

```@example 1
f.online
```

and the offline tree holds our 10 MC events:

```@example 1
f.offline
```

### Events

To access a single event, you can use the usual indexing syntax:

```@example 1
some_event = f.offline[5]
```

or ranges of events:

```@example 1
events = f.offline[6:9]
```

Each event consists of a vector of hits, MC hits, tracks and MC tracks. Depending
on the file, they may be empty.
