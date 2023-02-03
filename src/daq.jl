# Online DAQ readout

function Base.read(s::IO, ::Type{T}; legacy=false) where T<:DAQEvent
    length = read(s, Int32)
    type = read(s, Int32)
    version = Int16(0)
    !legacy && (version = read(s, Int16))
    det_id = read(s, Int32)
    run_id = read(s, Int32)
    timeslice_id = read(s, Int32)
    _timestamp_field = read(s, UInt32)
    whiterabbit_status = _timestamp_field & 0x80000000  # most significant bit
    timestamp = _timestamp_field & 0x7FFFFFFF  # skipping the most significant bit
    ticks = read(s, UInt32)
    trigger_counter = read(s, Int64)
    trigger_mask = read(s, Int64)
    overlays = read(s, Int32)

    n_triggered_hits = read(s, Int32)
    triggered_hits = Vector{TriggeredHit}()
    sizehint!(triggered_hits, n_triggered_hits)
    triggered_map = Dict{Tuple{Int32, UInt8, Int32, UInt8}, Int64}()
    @inbounds for i ∈ 1:n_triggered_hits
        dom_id = read(s, Int32)
        channel_id = read(s, UInt8)
        time = bswap(read(s, Int32))
        tot = read(s, UInt8)
        trigger_mask = read(s, Int64)
        triggered_map[(dom_id, channel_id, time, tot)] = trigger_mask
        push!(triggered_hits, TriggeredHit(dom_id, channel_id, time, tot, trigger_mask))
    end

    n_hits = read(s, Int32)
    hits = Vector{Hit}()
    sizehint!(hits, n_hits)
    @inbounds for i ∈ 1:n_hits
        dom_id = read(s, Int32)
        channel_id = read(s, UInt8)
        time = bswap(read(s, Int32))
        tot = read(s, UInt8)
        key = (dom_id, channel_id, time, tot)
        triggered = false
        if haskey(triggered_map, key)
            triggered = true
        end
        push!(hits, Hit(channel_id, dom_id, time, tot, triggered))
    end

    T(det_id, run_id, timeslice_id, whiterabbit_status, timestamp, ticks, trigger_counter, trigger_mask, overlays, n_triggered_hits, triggered_hits, n_hits, hits)
end
