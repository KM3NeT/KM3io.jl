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

### Reconstructions

We pick the best reconstructed muon from the Jpp reconstruction chain using [`bestjppmuon`](@ref):

```@example 1
reco = bestjppmuon(f.offline[1])
```

All the attributes listed in the output above are accessible directly from the returned [`Trk`](@ref) object.

Using the [Dot Syntax feature of
Julia](https://docs.julialang.org/en/v1/manual/functions/#man-vectorized) to
vectorise the `bestjppmuon` function in order to call it on each event, we get a
`Vector{Union{Missing, Trk}}` with 10 elements, the same number as events.

```@example 1
recos = bestjppmuon.(f.offline)
```

!!! note

    Notice that [`bestjppmuon`](@ref) and other similar functions ([`bestaashower`](@ref), [`bestjppshower`](@ref)...) can return `missing` when there is no matching reconstructed track in an event.

### Fit Parameters

The fit parameters need a bit of special care. Since the KM3NeT offline
dataformat only stores a plain array of values due to historical reasons, we
need to know the index of a specific parameter beforehand. You should avoid
using hard-coded numbers to access the elements. Accessing `.fitinf` on any
reconstructed track will return an object of type [`FitInformation`](@ref),
which behaves like an array but takes care of the 1-based indexing nature of
Julia since the index definitions defined in the [KM3NeT
Dataformat](https://git.km3net.de/common/km3net-dataformat) are 0-based. These
index definitions are accessible under the `KM3io.FITPARAMETERS` namespace. If
you are for example interested in the `JGandalf Chi2` parameter, you can access
its value like this:

```@example 1
reco.fitinf[KM3io.FITPARAMETERS.JGANDALF_CHI2]
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

## [Offline Event Tape](@id offline_event_tape)

A convenient way of processing many files (or XRootD sources) event-by-event is
provided by the [`OfflineEventTape`](@ref). It can be instantiated with a list
of files/sources, a single file or a folder. The latter will be scanned upon
initialisation and the files will be sorted by their filename before added to
the list of sources.

The [`OfflineEventTape`](@ref) is a lazy data structure and only loads data
from disk when necessary, e.g. during the event loop iteration or when
seeking.

The following examples creates a on offline event tape with two files:

```@example 1
tape = OfflineEventTape(
    [
        datapath("offline", "numucc.root"),
        datapath("offline", "km3net_offline.root")
    ]
)
```

the tape implements the iterator and yields an [`Evt`](@ref) instance
in each iteration:

```@example 1
for event in tape
    @show event
end
```

The `seek` function can be used to set the start of iterations to a specific
position.

If an integer is passed, the tape will jump to the event #13 and potentially
skim over files/sources:

```@example 1
seek(tape, 13)

for event in tape
    @show event
end
```

Sometimes, when processing many files, it can be useful to jump to the
event which happened right after a specific date:

```@example 1
using Dates

seek(tape, DateTime("2019-08-29T00:00:22.200"))

for event in tape
    @show event
end
```

!!! note

    Events are not guaranteed to be sorted by time. When using `seek` with a date,
    the [`OfflineEventTape`] will set its position to the very first event which is
    after the specified date. It might happen however, that some of the following
    events are earlier in time.


The following example uses a tape instantiated with a folder containing 415 ROOT
files with a total size of 149 GB.

```@julia-repl
julia> using KM3io, Dates

julia> tape = OfflineEventTape("/Volumes/ECAP Data/data/KM3NeT_00000100/v9.2/dst")
OfflineEventTape(415 sources)

julia> seek(tape, DateTime("2022-01-02T10:23:45"))
OfflineEventTape(415 sources)

julia> position(tape)  # file #213, event at index 58136
(231, 58136)

julia> for event in tape
           @show event
           break
       end
event = Evt (0 hits, 0 MC hits, 2 tracks, 0 MC tracks)
```

The seek algorithm is implemented as a binary search to minimise the number of
ROOT files to be opened. In case of the dataset used in the example above, the
operation takes less than a second with a small footprint of about 230 MB, which
is dominated by caching:

```julia-repl
julia> @benchmark seek(tape, DateTime("2022-01-02T10:23:45"))
BenchmarkTools.Trial: 6 samples with 1 evaluation per sample.
 Range (min … max):  881.339 ms … 897.701 ms  ┊ GC (min … max): 1.22% … 2.23%
 Time  (median):     886.306 ms               ┊ GC (median):    2.09%
 Time  (mean ± σ):   888.006 ms ±   6.992 ms  ┊ GC (mean ± σ):  2.03% ± 0.44%

  █ █  █                         █                █           █
  █▁█▁▁█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█▁▁▁▁▁▁▁▁▁▁▁█ ▁
  881 ms           Histogram: frequency by time          898 ms <

 Memory estimate: 231.59 MiB, allocs estimate: 1612771.
```
