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

Water medium properties relevant for Cherenkov light. `n_phase` is the phase
index of refraction, which sets the Cherenkov angle (`cos θ_c = 1/n_phase`),
while `n_group` is the group index of refraction, which sets the photon group
velocity (`v = c/n_group`).

The default values are the ones used in `aanet`: `n_phase = 1.3499` and
`n_group = n_phase + 0.0298`, where the latter offset accounts for the
dispersion between phase and group velocity.

# Examples
```julia
Water()                                # aanet defaults
Water(n = 1.35)                        # set the phase index, derive the group index
Water(n_phase = 1.35, n_group = 1.38)  # set both indices independently
```

See also [`cherenkov`](@ref).
"""
struct Water
    n_phase::Float64
    n_group::Float64
end
function Water(; n=Constants.WATER_INDEX,
                n_phase=n,
                n_group=n_phase + Constants.DN_DL,
                λ=nothing,
                P=Constants.KM3NET_AMBIENT_PRESSURE)
    λ === nothing && return Water(n_phase, n_group)
    Water(_index_phase(λ, P), _index_group(λ, P))
end

# Jpp dispersion model (JDispersion.hh): phase index of refraction at wavelength
# λ [nm] and ambient pressure P [atm].
function _index_phase(λ, P)
    x = 1.0 / λ
    Constants.DISPERSION_A0 + Constants.DISPERSION_A1 * P +
        x * (Constants.DISPERSION_A2 + x * (Constants.DISPERSION_A3 + x * Constants.DISPERSION_A4))
end
# Dispersion dn/dλ of the phase index (pressure independent).
function _dispersion_phase(λ)
    x = 1.0 / λ
    -x * x * (Constants.DISPERSION_A2 + x * (2 * Constants.DISPERSION_A3 + x * 3 * Constants.DISPERSION_A4))
end
# Group index of refraction n_g = n / (1 + (dn/dλ)·λ/n).
function _index_group(λ, P)
    n = _index_phase(λ, P)
    n / (1.0 + _dispersion_phase(λ) * λ / n)
end

"""
    pressure_at_depth(depth)

Hydrostatic ambient pressure [atm] at the given `depth` [m] of sea water, using
the mean sea water density (`Constants.DENSITY_SEA_WATER`) and standard gravity
on top of one standard atmosphere at the surface.
"""
function pressure_at_depth(depth)
    g = 9.80665                            # standard gravity [m/s^2]
    ρ = Constants.DENSITY_SEA_WATER * 1e3  # [g/cm^3] -> [kg/m^3]
    P0 = 101325.0                          # standard atmosphere [Pa]
    (P0 + ρ * g * depth) / P0
end

"""

[`Water`](@ref) properties for the KM3NeT/ORCA site, evaluated with the Jpp
dispersion model at the reference wavelength (`Constants.REFERENCE_WAVELENGTH`,
460 nm) and the ambient pressure for a sea water depth of 2440 m.

"""
const WaterORCA = Water(λ=Constants.REFERENCE_WAVELENGTH, P=pressure_at_depth(2440.0))

"""

[`Water`](@ref) properties for the KM3NeT/ARCA site, evaluated with the Jpp
dispersion model at the reference wavelength (`Constants.REFERENCE_WAVELENGTH`,
460 nm) and the ambient pressure for a sea water depth of 3450 m.

"""
const WaterARCA = Water(λ=Constants.REFERENCE_WAVELENGTH, P=pressure_at_depth(3450.0))

"""

Calculates the parameters of cherenkov photons emitted from a track and hitting
the PMTs represented as (calibrated) hits. The returned cherenkov photons hold
information about the closest distance to track, the time residual, arrival
time, impact angle, photon travel distance, track travel distance and photon
travel direction. See [`CherenkovPhoton`](@ref) for more information.

The optional `water` argument ([`Water`](@ref)) sets the index of refraction
used for the Cherenkov angle (phase index) and for the photon group velocity
(group index). It defaults to the `aanet` values.

For the hit-based methods, the keyword `correct_slew` (default `false`) controls
whether a time-over-threshold slewing correction is applied to the hit time
before computing the time residual `Δt`, by subtracting `slew(hit.tot)` (see
[`slew`](@ref)). Keep it at `false` for hits whose time already includes the
slewing correction (e.g. offline hits written by Jpp with slewing enabled) to
avoid a double correction, and set it to `true` for slewing-free calibrated
times (such as those produced by [`calibratetime`](@ref) or [`calibrate`](@ref))
to follow the Jpp reconstruction convention.

"""
function cherenkov(track, hits::AbstractVector{<:AbstractCalibratedHit}, water::Water=Water(); correct_slew=false)
    [cherenkov(track, hit, water; correct_slew=correct_slew) for hit in hits]
end
function cherenkov(track, hit::AbstractCalibratedHit, water::Water=Water(); correct_slew=false)
    cherenkov(track, hit.pos, water; dir=hit.dir, t=time(hit; correct_slew=correct_slew))
end
function cherenkov(track, pos::Position, water::Water=Water(); dir::Union{Direction,Missing}=missing, t=0)
    cos_thetac = 1.0 / water.n_phase
    sin_thetac = √(1.0 - cos_thetac * cos_thetac)
    tan_thetac = sin_thetac / cos_thetac
    v_light_water = Constants.C_LIGHT / water.n_group

    V = pos - track.pos
    L = V ⋅ track.dir
    d_closest = √((V ⋅ V) - L .* L)
    d_photon = d_closest / sin_thetac
    d_track = L - d_closest / tan_thetac
    _t = track.t + d_track / Constants.C_LIGHT + d_photon / v_light_water
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
(track::Track)(hit::AbstractCalibratedHit, water::Water=Water(); correct_slew=false) = cherenkov(track, hit, water; correct_slew=correct_slew)
(track::Track)(hit::Position, water::Water=Water(); dir::Union{Direction, Missing}=missing, t=0) = cherenkov(track, hit, water; dir=dir, t=t)
(track::Track)(hits::AbstractVector{<:AbstractCalibratedHit}, water::Water=Water(); correct_slew=false) = cherenkov(track, hits, water; correct_slew=correct_slew)

"""

Converts times between the Monte Carlo event frame (`t = 0` at the simulated
event time) and the DAQ/trigger frame used by the calibrated hits and the
reconstructed tracks. A single additive `offset` [ns] captures the conversion,
derived from the event's run-relative generation time `mc_t` and its
`frame_index`:

    offset = mc_t - frame_start,   frame_start = frame_index > 0 ? (frame_index - 1) * FRAME_TIME : 0

Only the (small, order 1e7 ns) difference is stored, which preserves nanosecond
precision in `Float64`. Build it from an offline event and apply it with
[`mc2daq`](@ref) / [`daq2mc`](@ref).

This is meaningful for MC events with a populated `frame_index`, as produced by
the Jpp reconstruction of offline files. On real data or events without frame
timing (`frame_index == 0`, `mc_t == 0`) the `offset` is not physically
meaningful.

# Examples
```julia
tc = TimeConverter(evt)         # from an offline event
mc2daq(tc, evt.mc_trks[1])      # MC track time -> DAQ frame
daq2mc(tc, evt.hits[1].t)       # DAQ hit time  -> MC frame
mc2daq.(tc, evt.mc_hits)        # broadcasts over the MC hits
```

See also [`mc2daq`](@ref), [`daq2mc`](@ref), [`cherenkov`](@ref).
"""
struct TimeConverter
    offset::Float64  # [ns]  t_daq = t_mc + offset
end
function TimeConverter(mc_t::Real, frame_index::Integer)
    frame_start = frame_index > 0 ? (frame_index - 1) * Constants.FRAME_TIME : 0.0
    TimeConverter(mc_t - frame_start)
end
TimeConverter(e::Evt) = TimeConverter(e.mc_t, e.frame_index)

Base.show(io::IO, tc::TimeConverter) = print(io, "TimeConverter(offset=$(tc.offset) ns)")

# Treat the converter as a scalar in broadcasting, so `mc2daq.(tc, times)` works
# (a bare struct is otherwise iterated over).
Base.Broadcast.broadcastable(tc::TimeConverter) = Ref(tc)

"""

Convert a time [ns] from the Monte Carlo event frame to the DAQ/trigger frame
with a [`TimeConverter`](@ref). Also accepts an `MCTrk` or `CalibratedMCHit` and
converts its time.

See also [`daq2mc`](@ref), [`TimeConverter`](@ref).
"""
mc2daq(tc::TimeConverter, t::Real) = t + tc.offset
mc2daq(tc::TimeConverter, x::Union{MCTrk,CalibratedMCHit}) = mc2daq(tc, x.t)

"""

Convert a time [ns] from the DAQ/trigger frame to the Monte Carlo event frame
with a [`TimeConverter`](@ref). Also accepts a `Trk` or `CalibratedHit` and
converts its time.

See also [`mc2daq`](@ref), [`TimeConverter`](@ref).
"""
daq2mc(tc::TimeConverter, t::Real) = t - tc.offset
daq2mc(tc::TimeConverter, x::Union{Trk,CalibratedHit}) = daq2mc(tc, x.t)

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
