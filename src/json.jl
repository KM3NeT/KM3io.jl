"""
    function tojson(filename::AbstractString, e::Evt)

Writes an offline event ([`Evt`]@ref) as a JSON string to a file.
"""
function tojson(filename::AbstractString, event::Evt, detector::Detector; track_time_offset=0)
    open(filename, "w") do io
        tojson(io, event, detector; track_time_offset=track_time_offset)
    end
end

function tojson(io::IO, event::Evt, detector::Detector; track_time_offset=0)
    bt = bestjppmuon(event)
    t₀ = first(event.hits).t

    hits = [
        (
            dom_id = h.dom_id,
            channel_id = h.channel_id,
            floor = detector[h.dom_id].location.floor,
            detection_unit = detector[h.dom_id].location.string,
	    tdc = h.tdc,
            t = h.t - t₀,
            tot = h.tot,
            pos_x = h.pos.x, pos_y = h.pos.y, pos_z = h.pos.z,
            dir_x = h.dir.x, dir_y = h.dir.y, dir_z = h.dir.z,
            triggered = h.trigger_mask > 0
        ) for h in event.hits
    ]
    if !ismissing(bt)
        bt = (
            pos_x = bt.pos.x, pos_y = bt.pos.y, pos_z = bt.pos.z,
            dir_x = bt.dir.x, dir_y = bt.dir.y, dir_z = bt.dir.z,
            t = bt.t - t₀ + track_time_offset
        )
    end

    JSON.print(io, (utc_timestamp=event.t.s + (event.t.ns + t₀)/1e9, hits=hits, reconstructed_track=bt))
end

function tojson(filename::AbstractString, detector::Detector)
    open(filename, "w") do io
        tojson(io, detector)
    end
end

function tojson(io::IO, detector::Detector)
    modules = [
        (
            id=m.id, detection_unit=m.location.string, floor=m.location.floor, pos_x = m.pos.x, pos_y = m.pos.y, pos_z = m.pos.z,
            pmts=[(id=channel_id - 1, pos_x=p.pos.x, pos_y=p.pos.y, pos_z=p.pos.z, dir_x=p.dir.x, dir_y=p.dir.y, dir_z=p.dir.z) for (channel_id, p) in enumerate(m)]
        )
        for m in detector
    ]
    JSON.print(io, modules)
end
