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

# Examples
```
t = OfflineEventTape(["somefile.root", "anotherfile.root"])

for event in t
    # process the offline event
end
```

"""
mutable struct OfflineEventTape
    sources::Vector{String}
    event_counts::Vector{Int}
    current_file::ROOTFile
    current_sidx::Int

    function OfflineEventTape(sources::Vector{String})
        f = ROOTFile(sources |> first)
        event_counts = Int[length(f.offline)]
        new(sources, event_counts, f, 1)
    end
end
Base.eltype(::OfflineEventTape) = Evt
function Base.iterate(t::OfflineEventTape, state=(1, 1))
    if state > (length(t.sources), last(t.event_counts))
        # reset and end iteration
        t.current_file = ROOTFile(t.sources |> first)
        t.current_sidx = 1
        return nothing
    end
    source_idx, event_idx = state
    if event_idx > t.event_counts[source_idx]
        event_idx = 1
        source_idx += 1
        if length(t.event_counts) < source_idx
            push!(t.event_counts, length(ROOTFile(t.sources[source_idx])))
        end
        for event_count in t.event_counts[source_idx:end]
            if event_count == 0
                source_idx += 1
            else
                break
            end
        end
        source_idx > length(t.sources) && return nothing # no more files with events left
        t.current_file = ROOTFile(t.sources[source_idx])
        t.current_sidx = source_idx
    end
    (t.current_file.offline[event_idx], (source_idx, event_idx+1))
end
function Base.show(io::IO, t::OfflineEventTape)
    print(io, "OfflineEventTape($(length(t.sources)) sources, $(t.n_events) events)")
end
