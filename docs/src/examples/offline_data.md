# Offline data

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

## Events

To access a single event, you can use the usual indexing syntax:

```@example 1
some_event = f.offline[5]
```

or ranges of events:

```@example 1
events = f.offline[6:9]
```

Another way to access events is given by getter function `getevent()` (which also works for online trees). If a
single number if passed, it will be treated as a regular index, just like above:

```@example 1
event = getevent(f.offline, 3)
```

when two numbers are passed, the first one is interpreted as `frame_index` and the second one as `trigger_counter`:

```@example 1
event = getevent(f.offline, 87, 2)
```

### Hits

Each event consists of a vector of hits, MC hits, tracks and MC tracks. Depending
on the file, they may be empty. They are accessible via the fields `.hit`, `.mc_hits`, `.trks` and `.mc_trks`.

Let's grab an event:

```@example 1
evt = f.offline[3]
```

and have a look at its contents:

```@example 1
evt.hits
```

Let's close this file properly:

```@example 1
close(f)
```

### Usr data

You can also access "usr"-data, which is a dynamic placeholder (`Dict{String,
Float64}`) to store arbitrary data. Some software store values here which are
only losely defined. Ideally, if these fields are used regulary by a software, a
proper definition in the KM3NeT dataformat should be created and added to the
according `Struct` as a field.

Here is an example how to access the "usr"-data of a single event:

```@example 1
f = ROOTFile(datapath("offline", "usr-sample.root"))

f.offline[1].usr
```

```@example 1
close(f)
```
