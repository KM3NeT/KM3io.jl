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
