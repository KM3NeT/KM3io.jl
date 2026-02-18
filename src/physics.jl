"""

A Cherenkov photon with parameters calculated from its inducing track. See
[`cherenkov()`](@ref) for more information.

"""
struct CherenkovPhoton
    d_closest::Float64
    d_photon::Float64
    d_track::Float64
    t::Float64
    Δt::Float64
    impact_angle::Float64
    dir::Direction{Float64}
end


"""

Calculates the parameters of cherenkov photons emitted from a track and hitting
the PMTs represented as (calibrated) hits. The returned cherenkov photons hold
information about the closest distance to track, the time residual, arrival
time, impact angle, photon travel distance, track travel distance and photon
travel direction. See [`CherenkovPhoton`](@ref) for more information.

"""
cherenkov(track, hits::Vector{T}) where {T<:AbstractCalibratedHit} = [cherenkov(track, h) for h ∈ hits]
cherenkov(track, hit::AbstractCalibratedHit) = cherenkov(track, hit.pos; dir=hit.dir, t=hit.t)
function cherenkov(track, pos::Position; dir::Union{Direction,Missing}=missing, t=0)
    V = pos - track.pos
    L = V ⋅ track.dir
    d_closest = √((V ⋅ V) - L .* L)
    d_photon = d_closest / Constants.SIN_CHERENKOV
    d_track = L - d_closest / Constants.TAN_CHERENKOV
    _t = track.t + d_track / Constants.C_LIGHT + d_photon / Constants.V_LIGHT_WATER
    Δt = t - _t
    _pos = V - (d_track * track.dir)
    _dir = normalize(_pos)
    impact_angle = ismissing(dir) ? NaN : _dir ⋅ dir
    CherenkovPhoton(
        d_closest,
        d_photon,
        d_track,
        _t,
        Δt,
        impact_angle,
        _dir
    )
end
(track::Track)(hit::AbstractCalibratedHit) = cherenkov(track, hit)
(track::Track)(hit::Position; dir::Union{Direction, Missing}=missing, t=0) = cherenkov(track, hit; dir=dir, t=t)
(track::Track)(hits::Vector{CalibratedHit}) = cherenkov(track, hits)

"""

K40 rates with L0 and higher level rates (with increasing multiplicities).

"""
struct K40Rates
    L0::Float64
    L1::Vector{Float64}
end

"""
Returns a `K40Rates` object with default values for KM3NeT.

The singles and multiples rates are based on Analysis [e-log entry 597](https://elog.km3net.de/Analysis/597)
A dark count of 700 Hz has been included in the singles rate.
See also [KM3NeT internal note - Simulation Description](https://simulation.pages.km3net.de/input_tables/Simulations_Description.pdf)
"""
K40Rates() = K40Rates(5200, [568.0, 49.10, 5.48, 0.48])

"""
Return the absorption length [m] in water at a KM3NeT site for a given wavelength [nm].
"""
function absorptionlength(λ)
    error("Not implemented yet.")
end
