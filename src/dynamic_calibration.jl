const _PIEZO_DZ = -0.20  # piezo is 0.20 m below the module centre in z

"""
    DynamicCalibration(det::Detector; position_file, orientation_file)

Container for dynamic calibration data that can be applied per-module at a given
timestamp.  Both `position_file` (`DynamicPositionFile`) and `orientation_file`
(`DynamicOrientationFile`) are optional keyword arguments.

Use [`calibrate`](@ref) to apply the calibration to a single [`DetectorModule`](@ref).
"""
struct DynamicCalibration
    det::Detector
    _position_file::Union{Nothing, DynamicPositionFile}
    _orientation_file::Union{Nothing, DynamicOrientationFile}
    # Pre-computed per-string position calibration lookups
    _str_times::Dict{Int32, Vector{Float64}}
    _str_fits::Dict{Int32, Vector{AcousticsFit}}
    _str_anchor::Dict{Int32, Position{Float64}}
    _mechanics::Union{Nothing, StringMechanics}
end

function DynamicCalibration(det::Detector;
                             position_file::Union{Nothing, DynamicPositionFile}=nothing,
                             orientation_file::Union{Nothing, DynamicOrientationFile}=nothing)
    str_times  = Dict{Int32, Vector{Float64}}()
    str_fits   = Dict{Int32, Vector{AcousticsFit}}()
    str_anchor = Dict{Int32, Position{Float64}}()
    mechanics  = nothing

    if !isnothing(position_file) && !isnothing(position_file._calibration_sets)
        mechanics = detector_mechanics(position_file)
        for cal in position_file._calibration_sets.calibrations
            t_mid = 0.5 * (cal.header.timestart + cal.header.timestop)
            for fit in cal.fits
                sid = Int32(fit.id)
                push!(get!(Vector{Float64},      str_times, sid), t_mid)
                push!(get!(Vector{AcousticsFit}, str_fits,  sid), fit)
            end
        end
        for sid in keys(str_times)
            ord            = sortperm(str_times[sid])
            str_times[sid] = str_times[sid][ord]
            str_fits[sid]  = str_fits[sid][ord]
        end
        for mod in values(det.modules)
            isbasemodule(mod) && (str_anchor[mod.location.string] = mod.pos)
        end
    end

    DynamicCalibration(det, position_file, orientation_file,
                       str_times, str_fits, str_anchor, mechanics)
end

function Base.show(io::IO, dc::DynamicCalibration)
    pos = isnothing(dc._position_file)    ? "no position"    : "position"
    ori = isnothing(dc._orientation_file) ? "no orientation" : "orientation"
    print(io, "DynamicCalibration(det=$(dc.det.id), $pos, $ori)")
end

function _apply_position(dc::DynamicCalibration, mod::DetectorModule, t::Real)
    isbasemodule(mod)        && return mod
    isnothing(dc._mechanics) && return mod

    sid = mod.location.string
    haskey(dc._str_times,  sid) || return mod
    haskey(dc._str_anchor, sid) || return mod

    ts = dc._str_times[sid]
    (t < ts[1] || t > ts[end]) && return mod

    anchor = dc._str_anchor[sid]
    mech   = dc._mechanics[Int(sid)]

    piezo_z = mod.pos.z + _PIEZO_DZ
    height  = sqrt((mod.pos.x - anchor.x)^2 + (mod.pos.y - anchor.y)^2 + (piezo_z - anchor.z)^2)

    floor_dx = mod.pos.x - anchor.x
    floor_dy = mod.pos.y - anchor.y

    fit_interp = _interpolate_acoustics_fit(ts, dc._str_fits[sid], Float64(t))
    (dx, dy, dz) = _string_displacement(fit_interp, mech, height)

    new_pos = Position{Float64}(
        anchor.x + dx + floor_dx,
        anchor.y + dy + floor_dy,
        anchor.z + dz - _PIEZO_DZ,
    )

    Δx = new_pos.x - mod.pos.x
    Δy = new_pos.y - mod.pos.y
    Δz = new_pos.z - mod.pos.z
    new_pmts = [PMT(p.id, Position{Float64}(p.pos.x + Δx, p.pos.y + Δy, p.pos.z + Δz),
                    p.dir, p.t₀, p.status) for p in mod.pmts]

    DetectorModule(mod.id, new_pos, mod.location, mod.n_pmts,
                   new_pmts, mod.q, mod.status, mod.t₀)
end

function _apply_orientation(dc::DynamicCalibration, mod::DetectorModule, t::Real)
    isnothing(dc._orientation_file) && return mod
    haskey(dc._orientation_file._lookup, Int32(mod.id)) || return mod
    Q = orientation(dc._orientation_file, mod.id, t)
    calibrate_orientation(mod, Q)
end

"""
    calibrate(dc::DynamicCalibration, mod::DetectorModule, t::Real) -> DetectorModule

Apply dynamic position and/or orientation calibration to `mod` at UNIX time `t` [s].
Position calibration is applied first (if available for the module's string at `t`),
followed by orientation calibration (if compass data exists for the module at `t`).
Returns `mod` unchanged if no calibration data is available.
"""
function calibrate(dc::DynamicCalibration, mod::DetectorModule, t::Real)
    mod = _apply_position(dc, mod, t)
    _apply_orientation(dc, mod, t)
end
