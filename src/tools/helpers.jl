"""
A basic container type to assist the matching of MC events in the offline tree
with the events in the online tree.
"""
# TODO: add tests (need a proper testfile in km3net-testdata)
struct MCEventMatcher
    f::ROOTFile
end
Base.length(itr::MCEventMatcher) = length(itr.f.online.events)
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


"""

An iterator which yields a `Vector{Summaryslice}` containing summaryslices of a given
`time_interval` (in seconds). Useful when analysing summary data with fixed time intervals.
The returned summaryslices are also sorted in time.

"""
struct SummarysliceIntervalIterator
  sc::KM3io.SummarysliceContainer
  time_interval::Int  # [s]
  n_chunks::Int
  timespan::Float64
  indices::Vector{Int}
  function SummarysliceIntervalIterator(f::ROOTFile, time_interval)
    ss = f.online.summaryslices
    sorted_summaryslice_indices = sortperm([sh.frame_index for sh in ss.headers])
    timespan = ss.headers[sorted_summaryslice_indices[end]].frame_index / 10
    n_chunks = Int(ceil(timespan / time_interval))
    new(f.online.summaryslices, time_interval, n_chunks, timespan, sorted_summaryslice_indices)
  end
end
function Base.show(io::IO, sii::SummarysliceIntervalIterator)
    print(io, "SummarysliceIntervalIterator ($(sii.timespan)s, $(sii.time_interval)s intervals, $(sii.n_chunks) chunks)")
end
Base.eltype(::Type{SummarysliceIntervalIterator}) = Vector{KM3io.Summaryslice}
Base.length(sii::SummarysliceIntervalIterator) = sii.n_chunks
function Base.iterate(sii::SummarysliceIntervalIterator, state=(chunk_idx=1, s_idx=1))
  state.chunk_idx > sii.n_chunks && return nothing

  out_size = sii.time_interval * 10
  out = empty!(Vector{KM3io.Summaryslice}(undef, out_size))

  frame_index_upper = state.chunk_idx * sii.time_interval * 10

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
