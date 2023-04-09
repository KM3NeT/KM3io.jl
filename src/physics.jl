struct CherenkovPhoton
    d_closest::Float64
    d_photon::Float64
    d_track::Float64
    t::Float64
    impact_angle::Union{Float64, Missing}
    dir::Direction
end


"""
Calculates the parameters of cherenkov photons emitted from a track and hitting
the PMTs represented as (calibrated) hits.
"""
cherenkov(track, hits::Vector{EvtHit}) = [cherenkov(track, h) for h ∈ hits]
cherenkov(track, hit::AbstractCalibratedHit) = cherenkov(track, hit.pos; dir=hit.dir)

function cherenkov(track, pos::Position; dir::Union{Direction,Missing}=missing)
    V = pos - track.pos
    L = V ⋅ track.dir
    d_closest = √((V ⋅ V) - L .* L)
    d_photon = d_closest / SIN_CHERENKOV
    d_track = L - d_closest / TAN_CHERENKOV
    t = track.t + d_track / C_LIGHT + d_photon / V_LIGHT_WATER
    _pos = V - (d_track * track.dir)
    _dir = normalize(_pos)
    impact_angle = ismissing(dir) ? missing : _dir ⋅ dir
    CherenkovPhoton(
        d_closest,
        d_photon,
        d_track,
        t,
        impact_angle,
        _dir
    )
end
