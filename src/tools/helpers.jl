"""
A basic container type to assist run-by-run iteration.
"""
struct RBRIterator
    f::ROOTFile
end
Base.length(itr::RBRIterator) = length(itr.f.online.events)
function Base.iterate(itr::RBRIterator, state=1)
    state > length(itr) && return nothing
    event = f.online.events[state]
    mc_idx = event.header.trigger_counter + 1
    mc_event = itr.f.offline[mc_idx]
    ((event, mc_event), state + 1)
end
