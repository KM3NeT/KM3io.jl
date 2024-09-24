"""
    function tojson(filename::AbstractString, e::Evt)

Writes an offline event ([`Evt`]@ref) as a JSON string to a file.
"""
function tojson(filename::AbstractString, e::Evt)
    open(filename, "w") do io
        tojson(io, e::Evt)
    end
end

function tojson(io::IO, e::Evt)
    hits = [
        (
            dom_id = h.dom_id,
            channel_id = h.channel_id,
            t = h.t,
            tot = h.tot,
            pos_x = h.pos.x, pos_y = h.pos.y, pos_z = h.pos.z,
            dir_x = h.dir.x, dir_y = h.dir.y, dir_z = h.dir.z,
            triggered = h.trigger_mask > 0
        ) for h in e.hits
    ]
    bt = bestjppmuon(e)
    if !ismissing(bt)
        bt = (
            pos_x = bt.pos.x, pos_y = bt.pos.y, pos_z = bt.pos.z,
            dir_x = bt.dir.x, dir_y = bt.dir.y, dir_z = bt.dir.z,
            t=bt.t
        )
    end

    JSON.print(io, (utc_timestamp=e.t.s + e.t.ns/1e9, hits=hits, best_track=bt))
end
