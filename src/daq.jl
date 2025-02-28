# Online DAQ readout

function Base.read(s::IO, ::Type{T}; legacy=false) where T<:DAQEvent
    length = read(s, Int32)
    type = read(s, Int32)
    version = Int16(0)
    !legacy && (version = read(s, Int16))

    detector_id = read(s, Int32)
    run_id = read(s, Int32)
    frame_index = read(s, Int32)
    utc_seconds = read(s, UInt32)
    utc_16nanosecondcycles = read(s, UInt32) # 16ns ticks
    trigger_counter = read(s, Int64)
    trigger_mask = read(s, Int64)
    overlays = read(s, Int32)

    header = EventHeader(
        detector_id,
        run_id,
        frame_index,
        UTCExtended(utc_seconds, utc_16nanosecondcycles),
        trigger_counter,
        trigger_mask,
        overlays
    )

    n_triggered_hits = read(s, Int32)
    triggered_hits = Vector{TriggeredHit}()
    sizehint!(triggered_hits, n_triggered_hits)
    @inbounds for i ∈ 1:n_triggered_hits
        dom_id = read(s, Int32)
        channel_id = read(s, UInt8)
        time = bswap(read(s, Int32))
        tot = read(s, UInt8)
        trigger_mask = read(s, Int64)
        push!(triggered_hits, TriggeredHit(dom_id, channel_id, time, tot, trigger_mask))
    end

    n_hits = read(s, Int32)
    snapshot_hits = Vector{SnapshotHit}()
    sizehint!(snapshot_hits, n_hits)
    @inbounds for i ∈ 1:n_hits
        dom_id = read(s, Int32)
        channel_id = read(s, UInt8)
        time = bswap(read(s, Int32))
        tot = read(s, UInt8)
        key = (dom_id, channel_id, time, tot)
        triggered = false
        push!(snapshot_hits, SnapshotHit(dom_id, channel_id, time, tot))
    end

    T(header, snapshot_hits, triggered_hits)
end

function Base.write(io::IO, s::Summaryslice)
    # write(io, Int32(size?))
    # write(io, Int32(DAQDATATYPES.DAQSUMMARYSLICE))
    writestruct(io, s.header)
end
