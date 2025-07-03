"""

The main container for a `ROOTFile` which takes care of a proper initialisation
of all the custom bootstrapping needed to be able to read KM3NeT files.

The `filename` can be an XRootD path.

This struct shadows the name of `UnROOT.ROOTFile` for historic reasons. If you
use both `KM3io` and `UnROOT` in the same scope, prefixing will be required
(`UnROOT.ROOTFile` and `KM3io.ROOTFile`).

"""
struct ROOTFile
    _fobj::UnROOT.ROOTFile
    online::Union{OnlineTree, Nothing}
    offline::Union{OfflineTree, Nothing}

    function ROOTFile(filename::AbstractString)
        customstructs = Dict(
            "KM3NETDAQ::JDAQEvent.snapshotHits" => Vector{SnapshotHit},
            "KM3NETDAQ::JDAQEvent.triggeredHits" => Vector{TriggeredHit},
            "KM3NETDAQ::JDAQEvent.KM3NETDAQ::JDAQEventHeader" => EventHeader,
            "KM3NETDAQ::JDAQSummaryslice.KM3NETDAQ::JDAQSummarysliceHeader" => SummarysliceHeader,
            "KM3NETDAQ::JDAQSummaryslice.vector<KM3NETDAQ::JDAQSummaryFrame>" => Vector{SummaryFrame}
        )
        fobj = UnROOT.ROOTFile(filename, customstructs=customstructs)
        tpath_offline = ROOT.TTREE_OFFLINE_EVENT
        offline = tpath_offline ∈ keys(fobj) ? OfflineTree(fobj) : nothing
        tpath_online = ROOT.TTREE_ONLINE_EVENT
        online = tpath_online ∈ keys(fobj) ? OnlineTree(fobj) : nothing
        new(fobj, online, offline)
    end
end
Base.close(f::ROOTFile) = close(f._fobj)
function Base.show(io::IO, f::ROOTFile)
    s = String[]
    !isnothing(f.online) && push!(s, "$(f.online)")
    !isnothing(f.offline) && push!(s, "$(f.offline)")
    info = join(s, ", ")
    print(io, "ROOTFile{$info}")
end

"""
Returns true if the file contains offline events.
"""
hasofflineevents(f::ROOTFile) = !isnothing(f.offline) && length(f.offline) > 0


"""

A helper container which makes it easy to iterate over the offline
tree of many offline files. It automatically skips files which have
no offline events (due to an empty offline tree).

An optional progressbar can be shown during iteration by passing
`show_progress=true` to the constructor.

# Examples
```
t = OfflineEventTape(["somefile.root", "anotherfile.root"])

for event in t
    # process the offline event
end
```

Using a progress bar:

```
t = OfflineEventTape(["somefile.root", "anotherfile.root"]; show_progress=true)

for event in t
    # process the offline event
end
```

"""
mutable struct OfflineEventTape
    sources::Vector{String}
    show_progress::Bool
    start_at::Tuple{Int, Int}

    function OfflineEventTape(sources::Vector{String}; show_progress=false)
        return new(sources, show_progress, (1, 1))
    end
end
Base.eltype(::OfflineEventTape) = Evt
Base.IteratorSize(::OfflineEventTape) = Base.SizeUnknown()
"""
Seek to a given event position.
"""
function Base.seek(t::OfflineEventTape, n::Integer)
    n_events = 0
    for (source_idx, source) in enumerate(t.sources)
        f = ROOTFile(source)
        isnothing(f.offline) || length(f.offline) == 0 && continue
        n_events += length(f.offline)
        n > n_events && continue
        t.start_at = (source_idx, n - (n_events - length(f.offline)))
        return t
    end
    @warn "No event at position $n on this offline tape"
    t.start_at = (length(t.sources), length(ROOTFile(t.sources[end]).offline) + 1)
    t
end
"""
Seek to the first event which happened after the given datetime.

The strategy: check sources one-by-one and skip if the last event
is still earlier than the target event. Perform a binary search
on the first file which is not skipped.
"""
function Base.seek(t::OfflineEventTape, d::DateTime)
    for (source_idx, source) in enumerate(t.sources)
        f = ROOTFile(source)
        isnothing(f.offline) || length(f.offline) == 0 && continue
        last_event_datetime = DateTime(f.offline |> last)
        last_event_datetime < d && continue

        # f.offline["t/t.fSec", :] .+ f.offline["t/t.fNanoSec", :]./1e9
    end
end
function Base.iterate(t::OfflineEventTape)
    source_idx, event_idx = t.start_at
    n_sources = length(t.sources)

    p = Progress(n_sources - source_idx + 1; enabled=t.show_progress, showspeed=true, dt=0.5)

    while source_idx <= n_sources
        fname = t.sources[source_idx]
        f = ROOTFile(fname)
        next!(p; showvalues=[("file", fname)])
        if isnothing(f.offline) || length(f.offline) == 0
            close(f)
            source_idx += 1
            continue
        end
        return (f.offline[1], (source_idx, event_idx+1, f, p))
    end

    nothing
end
function Base.iterate(t::OfflineEventTape, state::Tuple{Int, Int, ROOTFile, Progress})
    source_idx, event_idx, _f, p = state
    source_idx > length(t.sources) && return nothing

    if event_idx > length(_f.offline)
        source_idx += 1
        if source_idx > length(t.sources)
            next!(p)
            return nothing
        end
        fname = t.sources[source_idx]
        next!(p; showvalues=[("file", fname)])
        return iterate(t, (source_idx, 1, ROOTFile(fname), p))
    end

    (_f.offline[event_idx], (source_idx, event_idx+1, _f, p))
end
function Base.show(io::IO, t::OfflineEventTape)
    print(io, "OfflineEventTape($(length(t.sources)) sources)")
end
