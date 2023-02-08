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
    ticks = read(s, UInt32) # 16ns ticks
    trigger_counter = read(s, Int64)
    trigger_mask = read(s, Int64)
    overlays = read(s, Int32)

    header = KM3NETDAQEventHeader(det_id, run_id, timeslice_id, timestamp, ticks, trigger_counter, trigger_mask, overlays)

    n_triggered_hits = read(s, Int32)
    triggered_hits = Vector{KM3NETDAQTriggeredHit}()
    sizehint!(triggered_hits, n_triggered_hits)
    @inbounds for i ∈ 1:n_triggered_hits
        dom_id = read(s, Int32)
        channel_id = read(s, UInt8)
        time = bswap(read(s, Int32))
        tot = read(s, UInt8)
        trigger_mask = read(s, Int64)
        push!(triggered_hits, KM3NETDAQTriggeredHit(dom_id, channel_id, time, tot, trigger_mask))
    end

    n_hits = read(s, Int32)
    snapshot_hits = Vector{KM3NETDAQSnapshotHit}()
    sizehint!(snapshot_hits, n_hits)
    @inbounds for i ∈ 1:n_hits
        dom_id = read(s, Int32)
        channel_id = read(s, UInt8)
        time = bswap(read(s, Int32))
        tot = read(s, UInt8)
        key = (dom_id, channel_id, time, tot)
        triggered = false
        push!(snapshot_hits, KM3NETDAQSnapshotHit(dom_id, channel_id, time, tot))
    end

    T(header, snapshot_hits, triggered_hits)
end
