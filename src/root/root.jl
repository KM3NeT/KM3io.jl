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
    dst::Union{DSTTree, Nothing}

    function ROOTFile(filename::AbstractString)
        customstructs = Dict(
            "KM3NETDAQ::JDAQEvent.snapshotHits" => Vector{SnapshotHit},
            "KM3NETDAQ::JDAQEvent.triggeredHits" => Vector{TriggeredHit},
            "KM3NETDAQ::JDAQEvent.KM3NETDAQ::JDAQEventHeader" => EventHeader,
            "KM3NETDAQ::JDAQSummaryslice.KM3NETDAQ::JDAQSummarysliceHeader" => SummarysliceHeader,
            "KM3NETDAQ::JDAQSummaryslice.vector<KM3NETDAQ::JDAQSummaryFrame>" => Vector{SummaryFrame}
        )
        fobj = UnROOT.ROOTFile(filename, customstructs=customstructs)
        keyset = keys(fobj)
        offline = ROOT.TTREE_OFFLINE_EVENT ∈ keyset ? OfflineTree(fobj) : nothing
        has_online = ROOT.TTREE_ONLINE_EVENT ∈ keyset || ROOT.TTREE_ONLINE_SUMMARYSLICE ∈ keyset
        online = has_online ? OnlineTree(fobj) : nothing
        new(fobj, online, offline)
    end
end
Base.close(f::ROOTFile) = close(f._fobj)
function Base.show(io::IO, f::ROOTFile)
    s = String[]
    !isnothing(f.online) && push!(s, "$(f.online)")
    !isnothing(f.offline) && push!(s, "$(f.offline)")
    !isnothing(f.dst) && push!(s, "$(f.dst)")
    info = join(s, ", ")
    print(io, "ROOTFile{$info}")
end

# A DST is identified by the presence of the "T" summary tree together
# with at least one DST-specific class streamer (guards against unrelated
# files that happen to carry a tree called "T").
function _is_dst(fobj::UnROOT.ROOTFile)
    TTREE_DST_SUMMARY ∈ keys(fobj) || return false
    for s ∈ fobj.streamers.elements
        s.streamer.fName ∈ ("MC_evts_summary", "MC_trks_summary", "hits_summary",
                            "rec_trks_summary", "cascade_summary", "crkv_hits") &&
            return true
    end
    false
end

"""
Returns true if the file contains offline events.
"""
hasofflineevents(f::ROOTFile) = !isnothing(f.offline) && length(f.offline) > 0

"""
Returns true if the file contains online events.
"""
hasonlineevents(f::ROOTFile) = !isnothing(f.online) && !isnothing(f.online.events) && length(f.online.events) > 0

"""
Returns true if the file contains summaryslices.
"""
hassummaryslices(f::ROOTFile) = !isnothing(f.online) && !isnothing(f.online.summaryslices) && length(f.online.summaryslices) > 0


"""

    OfflineEventTape(sources::Vector{String}; show_progress=false)
    OfflineEventTape(filename_or_path::AbstractString; show_progress=false)

A helper container which makes it easy to iterate over the offline
tree of many offline files. It automatically skips files which have
no offline events (due to an empty offline tree).

If a `filename_or_path` is pointing to an existing file, a single file will be
used. If it's a valid path, the directory will be scanned for ROOT files
and they will be sorted by filename.

An optional progressbar can be shown during iteration by passing
`show_progress=true` to the constructor.

# Examples
```
t = OfflineEventTape(["somefile.root", "anotherfile.root"])

for event in t
    # process the offline event
end
```

Using a directory containing ROOT files:

```
t = OfflineEventTape("/mnt/data/KM3NeT_00000100/v9.2/dst")

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
function OfflineEventTape(filename_or_path::AbstractString; show_progress=false)
    if isdir(filename_or_path)
        sources = filter(p->endswith(p, ".root"), readdir(filename_or_path; join=true)) |> sort
    elseif isfile(filename_or_path)
        sources = [filename_or_path]
    else
        throw(SystemError("opening file \"$filename_or_path\""))
    end
    OfflineEventTape(sources; show_progress=show_progress)
end
Base.eltype(::OfflineEventTape) = @NamedTuple{event::Evt, header::Union{MCHeader, Missing}}
Base.IteratorSize(::OfflineEventTape) = Base.SizeUnknown()
Base.position(t::OfflineEventTape) = t.start_at
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
    # Setting the index to the very end
    t.start_at = (length(t.sources)+1, 1)
    t
end
"""
Seek to the first event which happened after the given datetime.

The strategy: binary search for the source using first and last event
datetime, then check matching file's events with `findfirst` search.
If nothing is found, the pointer is set right after the last source
resulting in an empty iterator.
"""
function Base.seek(tape::OfflineEventTape, d::DateTime)
    low = 1
    high = length(tape.sources)
    t₀ = datetime2unix(d)

    while low <= high
        mid = low + (high - low)÷2
        i = mid
        # we need to do some "masking" since the offline tree might be missing
        # or can contain no events
        while i >=low && !hasofflineevents(ROOTFile(tape.sources[i]))
            i -= 1
        end
        if i < low
            i = mid + 1
            while i <= high && !hasofflineevents(ROOTFile(tape.sources[i]))
                i += 1
            end
        end
        if i < low || i > high
            # nothing found, setting the index to the very end
            tape.start_at = (length(tape.sources)+1, 1)
            return tape
        end

        f = ROOTFile(tape.sources[i])
        timestamps = f.offline["t/t.fSec", :] + f.offline["t/t.fNanoSec", :]*1e-9
        # events are not guaranteed to be sorted in time
        t_min, t_max = extrema(timestamps)
        if t_min <= t₀ <= t_max
            # got it, let's find the event
            # we do a simple `findfirst` here, since events are not time-sorted
            event_idx = findfirst(t -> t >= t₀, timestamps)
            tape.start_at = (i, event_idx)
            return tape
        elseif t₀ < t_min
            # we need to check if the date is between two runs
            _i = i - 1
            while _i > 0
                f = ROOTFile(tape.sources[_i])
                if hasofflineevents(f)
                    if t₀ > maximum(f.offline["t/t.fSec", :])
                        tape.start_at = (_i + 1, 1)
                        return tape
                    else
                        break
                    end
                end
                _i -= 1
            end
            high = i - 1
        else
            low = i + 1
        end
    end

    # nothing found, setting the index to the very end
    tape.start_at = (length(tape.sources)+1, 1)
    tape
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
        return ((;event=f.offline[event_idx], header=f.offline.header), (source_idx, event_idx+1, f, p))
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

    ((;event=_f.offline[event_idx], header=_f.offline.header), (source_idx, event_idx+1, _f, p))
end
function Base.show(io::IO, t::OfflineEventTape)
    print(io, "OfflineEventTape($(length(t.sources)) sources)")
end
