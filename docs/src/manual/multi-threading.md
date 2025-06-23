# Multi-Threading

`KM3io.jl` supports multi-threading on the event (both offline and online) and
summaryslice level out of the box due to Julia's built-in `Threads` package.

By default, the `julia` process uses a single thread. In order to increase the
number of threads, the `-t N_THREADS` option can be used. Alternatively, the
environment variable `JULIA_NUM_THREADS` can be exported and it will set the
number of threads automatically for each `julia` process executed in that shell
session. See the [Julia Documentation on
Multi-Threading](https://docs.julialang.org/en/v1/manual/multi-threading/) for
more information.

The
`Threads.@threads` macro can be used directly in front of event- or
summaryslice-loops like the following example demonstrates:

```@example 1
using KM3io
using KM3NeTTestData


f = ROOTFile(datapath("offline", "numucc.root"))

Threads.@threads for event in f.offline
    println("Processing event $(event.id)")
    sleep(rand()/10)  # to mimic varying processing times
end
```

!!! note

    The order of the items is not predefined when using threads.

Below is an example using an online file. In that example, the total number of
hits with a time of threshold (ToT) of more than 50ns is counted. Note that
accessing the same variable or object from multiple threads at the same time can
lead to race conditions and unexpected results.

!!! note

    Julia offers "atomic" operations which are guaranteed to be executed
    in a single cycle, so that no other threads are able to interfere. The input
    has to be an atomic type, which can be created using the `Threads.Atomic`
    parametric type.
    
Let's iterate over all online events and count the number of snapshot hits using
the ToT selection. `n` is a local variable inside the loop and is therefore
thread-safe. `n_big_hits` however is in the outer scope and multiple threads can
potentially access (read and modify) it the same time, so we use the type
`Threads.Atomic{Int}` and the thread-safe `atomic_add!` function instead of the
usual `+` operator.

```@example 1
f = ROOTFile(datapath("online", "km3net_online.root"))

tot_threshold = 50  # [ns]
n_big_hits = Threads.Atomic{Int}(0)

Threads.@threads for event in f.online.events

    n = 0
    for hit in event.snapshot_hits
        if hit.tot > tot_threshold
            n += 1
        end
    end

    Threads.atomic_add!(n_big_hits, n)
end

println("Number of big hits (tot > $(tot_threshold)): $(n_big_hits[])")
```
