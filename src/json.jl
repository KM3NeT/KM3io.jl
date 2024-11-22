"""
    function tojson(filename::AbstractString, e::Evt)

Writes an offline event ([`Evt`]@ref) as a JSON string to a file.
"""
function tojson(filename::AbstractString, event::Evt, detector::Detector)
    open(filename, "w") do io
        tojson(io, event, detector)
    end
end

function tojson(io::IO, event::Evt, detector::Detector)
    bt = bestjppmuon(event)
    t₀ = bt.t

    hits = [
        (
            dom_id = h.dom_id,
            channel_id = h.channel_id,
            floor = detector[h.dom_id].location.floor,
            string = detector[h.dom_id].location.string,
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
            t=0.0
        )
    end

    JSON.print(io, (utc_timestamp=event.t.s + event.t.ns/1e9, hits=hits, best_track=bt))
end
