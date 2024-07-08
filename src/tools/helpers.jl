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
getevent(::ROOTFile, args...) = error("The function `getevent()` requires either an online or an offline tree as first argument. Try for example `getevent(f.online, ...)`")
