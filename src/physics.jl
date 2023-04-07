struct CherenkovPhoton
    d_closest::Float64
    d_photon::Float64
    d_track::Float64
    t::Float64
    impact_angle::Float64
    dir::Direction
end

function cherenkov(track, hits)
    cphotons = sizehint!(Vector{CherenkovPhoton}(), length(hits))
    for hit ∈ hits
        V = hit.pos - track.pos
        L = V ⋅ track.dir
        d_closest = √((V ⋅ V) - L .* L)
        d_photon = d_closest / SIN_CHERENKOV
        d_track = L - d_closest / TAN_CHERENKOV
        t = track.t + d_track / C_LIGHT + d_photon / V_LIGHT_WATER
        pos = V - (d_track * track.dir)
        dir = normalize(pos)
        impact_angle = pos ⋅ hit.dir
        push!(cphotons, CherenkovPhoton(
            d_closest,
            d_photon,
            d_track,
            t,
            impact_angle,
            dir
        ))
    end
    cphotons
end
