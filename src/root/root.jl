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

    function OfflineEventTape(sources::Vector{String}; show_progress=false)
        return new(sources, show_progress)
    end
end
Base.eltype(::OfflineEventTape) = Evt
Base.IteratorSize(::OfflineEventTape) = Base.SizeUnknown()
function Base.iterate(t::OfflineEventTape)
    source_idx = 1
    event_idx = 1
    n_sources = length(t.sources)

    p = Progress(n_sources; enabled=t.show_progress, showspeed=true)

    while source_idx <= n_sources
        f = ROOTFile(t.sources[source_idx])
        if isnothing(f.offline) || length(f.offline) == 0
            close(f)
            source_idx += 1
            next!(p; showvalues=[("file", t.sources[source_idx])])
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
        next!(p; showvalues=[("filename", t.sources[source_idx])])
        source_idx > length(t.sources) && return nothing
        return iterate(t, (source_idx, 1, ROOTFile(t.sources[source_idx]), p))
    end

    (_f.offline[event_idx], (source_idx, event_idx+1, _f, p))
end
function Base.show(io::IO, t::OfflineEventTape)
    print(io, "OfflineEventTape($(length(t.sources)) sources)")
end
