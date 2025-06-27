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

    function OfflineEventTape(sources::Vector{String})
        f = ROOTFile(sources |> first)
        event_counts = Int[length(f.offline)]
        new(sources, event_counts, f)
    end
end
Base.eltype(::OfflineEventTape) = Evt
Base.IteratorSize(::OfflineEventTape) = Base.SizeUnknown()
function rewind!(t::OfflineEventTape)
    t.current_file = ROOTFile(t.sources |> first)
    t.event_counts = Int[length(t.current_file.offline)]
    return t
end
function Base.iterate(t::OfflineEventTape, state=(1, 1))
    if state[1] > length(t.sources) || (length(t.sources) == length(t.event_counts) && state[2] > t.event_counts[state[1]])
        # reset and end iteration
        rewind!(t)
        return nothing
    end
    source_idx, event_idx = state
    if event_idx > t.event_counts[source_idx]
        event_idx = 1
        source_idx += 1
	t.current_file = ROOTFile(t.sources[source_idx])
        if length(t.event_counts) < source_idx
	    if isnothing(t.current_file.offline)
                push!(t.event_counts, 0)
            else
                push!(t.event_counts, length(t.current_file.offline))
            end
        end
        for _sidx in source_idx:length(t.sources)
            if _sidx > length(t.event_counts)
                t.current_file = ROOTFile(t.sources[source_idx])
                if isnothing(t.current_file.offline)
                    push!(t.event_counts, 0)
                else
                    push!(t.event_counts, length(t.current_file.offline))
                end
            end
            event_count = t.event_counts[_sidx]
            if event_count == 0
                source_idx += 1
            else
                break
            end
        end
        if source_idx > length(t.sources)
            rewind!(t)
            return nothing # no more files with events left
        end
        t.current_file = ROOTFile(t.sources[source_idx])
    end
    (t.current_file.offline[event_idx], (source_idx, event_idx+1))
end
function Base.show(io::IO, t::OfflineEventTape)
    print(io, "OfflineEventTape($(length(t.sources)) sources)")
end
