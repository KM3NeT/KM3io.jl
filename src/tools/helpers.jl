"""
A basic container type to assist the matching of MC events in the offline tree
with the events in the online tree.
"""
# TODO: add tests (need a proper testfile in km3net-testdata)
struct MCEventMatcher
    f::ROOTFile
end
Base.length(itr::MCEventMatcher) = length(itr.f.online.events)
Base.size(itr::MCEventMatcher) = (length(itr),)
Base.lastindex(itr::MCEventMatcher) = length(itr)
function Base.getindex(itr::MCEventMatcher, idx::Integer)
    event = itr.f.online.events[idx]
    mc_idx = event.header.trigger_counter + 1
    mc_event = itr.f.offline[mc_idx]
    (event, mc_event)
end
function Base.iterate(itr::MCEventMatcher, state=1)
    state > length(itr) && return nothing
    (itr[state], state + 1)
end


countevents(tree::OfflineTree) = length(tree)
countevents(tree::OnlineTree) = length(tree.events)
countevents(tree::OscillationsData) = length(tree)
triggercounterof(e::Evt) = e.trigger_counter
frameindexof(e::Evt) = e.frame_index
triggercounterof(e::DAQEvent) = e.header.trigger_counter
frameindexof(e::DAQEvent) = e.header.frame_index

"""

Retrieves the event with for a given `frame_index` and `trigger_counter`.

"""
function getevent(tree::T, frame_index, trigger_counter) where T<:Union{OnlineTree, OfflineTree}
    lookup = tree._frame_index_trigger_counter_lookup_map
    key = (frame_index, trigger_counter)
    if haskey(lookup, key)
        event_idx = lookup[key]
        return getevent(tree, event_idx)
    end

    highest_event_idx = length(lookup) == 0 ? 0 : maximum(values(lookup))

    for event_idx in (highest_event_idx+1):countevents(tree)
        event = getevent(tree, event_idx)

        fi = frameindexof(event)
        tc = triggercounterof(event)
        lookup[(fi, tc)] = event_idx

        if fi == frame_index && tc == trigger_counter
            return event
        end
    end

    error("No online event found for frame_index=$(frame_index) and trigger_counter=$(trigger_counter).")
end
getevent(tree::OfflineTree, idx) = tree[idx]
getevent(tree::OnlineTree, idx) = tree.events[idx]
getevent(tree::OscillationsData, idx) = tree[idx]


"""

An iterator which yields a `Vector{Summaryslice}` containing summaryslices of a given
`time_interval` (in seconds). Useful when analysing summary data with fixed time intervals.
The returned summaryslices are also sorted in time.

# Examples
```julia-repl
julia> f = ROOTFile("KM3NeT_00000133_00014728.root")
ROOTFile{OnlineTree (83509 events, 106969 summaryslices)}

julia> sii = SummarysliceIntervalIterator(f, 60)
SummarysliceIntervalIterator (10739.7s, 60s intervals, 179 chunks)

julia> for summaryslices in sii
           @show length(summaryslices)
           @show summaryslices[1].header
           break
       end
length(summaryslices) = 599
(summaryslices[1]).header = SummarysliceHeader(133, 14728, 134, UTCExtended(1676246413, 400000000, 0))
```

!!! note
    Short time intervals (a few tens of seconds) will likely return
    `Vector{Summaryslice}`s with few entries in the first and last iterations
    due to a delay in run changes. The number of frames per summaryslice will
    gradually increase due to the asynchronous nature of the run transition. See
    the example below with a time inteval of 10s and 100 active optical modules.

```julia-repl
julia> sii = SummarysliceIntervalIterator(f, 10)
SummarysliceIntervalIterator (106.2s, 10s intervals, 11 chunks)

julia> for summaryslices in sii
           n = length(summaryslices)
           @show n
       end
n = 73
n = 100
n = 100
n = 100
n = 100
n = 100
n = 100
n = 100
n = 100
n = 96
n = 31
```

"""
struct SummarysliceIntervalIterator
  sc::SummarysliceContainer
  first_frame_index::Int
  time_interval::Int  # [s]
  n_chunks::Int
  timespan::Float64
  indices::Vector{Int}
  function SummarysliceIntervalIterator(f::ROOTFile, time_interval)
    ss = f.online.summaryslices
    sorted_summaryslice_indices = sortperm([sh.frame_index for sh in ss.headers])
    first_frame_index = first(f.online.summaryslices).header.frame_index
    timespan = (ss.headers[sorted_summaryslice_indices[end]].frame_index - ss.headers[first(sorted_summaryslice_indices)].frame_index) / 10
    n_chunks = Int(ceil(timespan / time_interval))
    new(f.online.summaryslices, first_frame_index, time_interval, n_chunks, timespan, sorted_summaryslice_indices)
  end
end
function Base.show(io::IO, sii::SummarysliceIntervalIterator)
    print(io, "SummarysliceIntervalIterator ($(sii.timespan)s, $(sii.time_interval)s intervals, $(sii.n_chunks) chunks)")
end
Base.eltype(::Type{SummarysliceIntervalIterator}) = Vector{KM3io.Summaryslice}
Base.length(sii::SummarysliceIntervalIterator) = sii.n_chunks
Base.size(sii::SummarysliceIntervalIterator) = (length(sii),)
function Base.iterate(sii::SummarysliceIntervalIterator, state=(chunk_idx=1, s_idx=1))
  state.chunk_idx > sii.n_chunks && return nothing

  out_size = sii.time_interval * 10
  out = empty!(Vector{KM3io.Summaryslice}(undef, out_size))

  frame_index_upper = sii.first_frame_index + state.chunk_idx * sii.time_interval * 10

  s_idx = state.s_idx
  while s_idx <= length(sii.indices)
    idx = sii.indices[s_idx]
    summaryslice = sii.sc[idx]
    if summaryslice.header.frame_index < frame_index_upper
      push!(out, summaryslice)
      s_idx += 1
    else
      break
    end
  end

  return (out, (chunk_idx=state.chunk_idx+1, s_idx=s_idx))
end
