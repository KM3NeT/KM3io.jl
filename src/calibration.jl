"""
    reference_rotation(mod::DetectorModule) -> Quaternion

Compute the rotation quaternion `Q0` that maps the canonical (factory reference)
PMT directions ([`CANONICAL_PMT_DIRECTIONS`](@ref)) to the current static PMT
directions stored in `mod`.

This replicates Jpp's `getRotation(canonical_module, static_module)` using a
modified Gram-Schmidt process on all 31 PMT direction pairs, keeping only the
first three orthonormal basis vectors to build the rotation matrix, which is
then converted to a quaternion.

PMTs are paired by `pmt.id` (1–31), which corresponds to channel (TDC) order
for Jpp-generated DETX/DATX files.
"""
function reference_rotation(mod::DetectorModule)
    N = length(mod.pmts)
    # Mutable copies: canonical and static direction vectors, paired by channel index.
    # mod.pmts is in channel order (0..N-1) for Jpp-generated DETX/DATX files, and
    # CANONICAL_PMT_DIRECTIONS is stored in the same channel order.
    in_vecs  = [[CANONICAL_PMT_DIRECTIONS[i].x,
                 CANONICAL_PMT_DIRECTIONS[i].y,
                 CANONICAL_PMT_DIRECTIONS[i].z] for i in 1:N]
    out_vecs = [[p.dir.x, p.dir.y, p.dir.z] for p in mod.pmts]

    # Gram-Schmidt: orthonormalise the first 3 directions (Jpp convention)
    for i in 1:3
        # pick the remaining vector with the largest squared norm
        pos = i
        max_len2 = sum(x -> x^2, in_vecs[i])
        for j in i+1:N
            len2 = sum(x -> x^2, in_vecs[j])
            if len2 > max_len2
                max_len2 = len2
                pos = j
            end
        end

        u = sqrt(sum(x -> x^2, in_vecs[pos]))
        in_vecs[pos]  ./= u
        out_vecs[pos] ./= u

        if pos != i
            in_vecs[i],  in_vecs[pos]  = in_vecs[pos],  in_vecs[i]
            out_vecs[i], out_vecs[pos] = out_vecs[pos], out_vecs[i]
        end

        # remove component along the new basis vector from all remaining vectors
        for j in i+1:N
            d = sum(in_vecs[i] .* in_vecs[j])
            in_vecs[j]  .-= d .* in_vecs[i]
            out_vecs[j] .-= d .* out_vecs[i]
        end
    end

    # Build rotation matrix R = Σ_k out[k] ⊗ in[k]ᵀ  (R*in[k] = out[k])
    R = zeros(3, 3)
    for k in 1:3, a in 1:3, b in 1:3
        R[a, b] += out_vecs[k][a] * in_vecs[k][b]
    end

    rotation_matrix_to_quaternion(R)
end


"""
    calibrate_orientation(mod::DetectorModule, Q_dynamic::Quaternion) -> DetectorModule

Apply dynamic orientation calibration to a module following Jpp's `JDynamics`
algorithm:

1. Compute `Q0 = reference_rotation(mod)` — the rotation from the canonical
   (factory) frame to the current static geometry, derived from the actual PMT
   direction vectors via Gram-Schmidt (matching Jpp's `getRotation`).
2. Compute `Q1 = mod.q ⊗ Q_dynamic` — the combined static + compass rotation.
3. Apply the delta `Δ = Q1 ⊗ conj(Q0)` to all PMT directions as a sandwich
   product `Δ ⊗ d_pure ⊗ conj(Δ)`.

`Q_dynamic` is the interpolated compass reading at the time of interest, e.g.
from [`orientation`](@ref).  Returns a new `DetectorModule` with updated PMT
directions and `q` field set to `Q1`.
"""
function calibrate_orientation(mod::DetectorModule, Q_dynamic::Quaternion)
    Q0 = reference_rotation(mod)   # from PMT directions (Jpp: getRotation)
    Q1 = mod.q ⊗ Q_dynamic         # Q_static * Q_dynamic
    Δ  = Q1 ⊗ conj(Q0)
    rotated_pmts = map(mod.pmts) do p
        r_dir = Δ ⊗ Quaternion(zero(Float64), p.dir.x, p.dir.y, p.dir.z) ⊗ conj(Δ)
        # Rotate PMT position around the module centre (positions are absolute world-frame)
        rel_x = p.pos.x - mod.pos.x
        rel_y = p.pos.y - mod.pos.y
        rel_z = p.pos.z - mod.pos.z
        r_pos = Δ ⊗ Quaternion(zero(Float64), rel_x, rel_y, rel_z) ⊗ conj(Δ)
        new_pos = Position{Float64}(mod.pos.x + r_pos.qx, mod.pos.y + r_pos.qy, mod.pos.z + r_pos.qz)
        PMT(p.id, new_pos, Direction(r_dir.qx, r_dir.qy, r_dir.qz), p.t₀, p.status)
    end
    DetectorModule(mod.id, mod.pos, mod.location, mod.n_pmts, rotated_pmts, Q1, mod.status, mod.t₀)
end

"""

Apply full geometry and time calibration to given hits. This way of calibration
should be used wisely since it creates a very bloaded [`XCalibratedHit`](@ref)
object, which might not be necessary. Often, we only need time the calibration
to be applied.

"""
function calibrate(det::Detector, hits)
    calibrated_hits = Vector{XCalibratedHit}()
    has_trigger_mask = :trigger_mask ∈ fieldnames(eltype(hits))
    for hit in hits
        dom_id = hit.dom_id
        channel_id = hit.channel_id
        tot = hit.tot
        pos = det[dom_id][channel_id].pos
        dir = det[dom_id][channel_id].dir
        t0 = det[dom_id][channel_id].t₀
        t = hit.t + t0
        string = det[dom_id].location.string
        floor = det[dom_id].location.floor
        trigger_mask = has_trigger_mask ? hit.trigger_mask : 0
        c_hit = XCalibratedHit(
            dom_id, channel_id, t, tot, trigger_mask,
            pos, dir, t0,
            string, floor
        )
        push!(calibrated_hits, c_hit)
    end
    calibrated_hits
end

Base.time(det::Detector, hit; correct_slew=true) = time(hit; correct_slew=correct_slew) + getpmt(det, hit).t₀

"""

Calibrate the time of a given array of snapshot hits.

"""
function calibratetime(det::Detector, hits::Vector{T}) where T<:SnapshotHit
    out = sizehint!(Vector{CalibratedSnapshotHit}(), length(hits))
    for h in hits
        push!(out, CalibratedSnapshotHit(h.dom_id, h.channel_id, h.t + getpmt(det, h).t₀, h.tot))
    end
    out
end

"""

Calibrate the time of a given array of triggered hits.

"""
function calibratetime(det::Detector, hits::Vector{T}) where T<:TriggeredHit
    out = sizehint!(Vector{CalibratedTriggeredHit}(), length(hits))
    for h in hits
        push!(out, CalibratedSnapshotHit(h.dom_id, h.channel_id, h.t + getpmt(det, h).t₀, h.tot, h.trigger_mask))
    end
    out
end

"""
Combine snapshot and triggered hits to a single hits-vector.

This should be used to transfer the trigger information to the
snapshot hits from a DAQEvent. The triggered hits are a subset
of the snapshot hits.

"""
function combine(snapshot_hits::Vector{KM3io.SnapshotHit}, triggered_hits::Vector{KM3io.TriggeredHit})
    triggermasks = Dict{Tuple{UInt8, Int32, Int32, UInt8}, Int64}()
    for hit ∈ triggered_hits
        triggermasks[(hit.channel_id, hit.dom_id, hit.t, hit.tot)] = hit.trigger_mask
    end
    n = length(snapshot_hits)
    hits = sizehint!(Vector{TriggeredHit}(), n)
    for hit in snapshot_hits
        channel_id = hit.channel_id
        dom_id = hit.dom_id
        t = hit.t
        tot = hit.tot
        triggermask = get(triggermasks, (channel_id, dom_id, t, tot), 0)
        push!(hits, TriggeredHit(dom_id, channel_id, t, tot, triggermask))
    end
    hits
end


"""
Calculates the average floor distance between neighboured modules.
"""
function floordist(det::Detector)
    floordistances = Float64[]
    for s ∈ det.strings
        # all the modules on the string, except the base module
        modules = [m for m in det if m.location.string == s && m.location.floor != 0 ]
        # collecting the z position for the same PMT channel (0) on each module
        push!(floordistances, mean(diff(sort(collect(m.pos.z for m ∈ modules)))))
    end
    mean(floordistances)
end

"""
Return the time slewing for a ToT.
"""
slew(tot::Integer) = @inbounds ifelse(tot < 256, SLEWS[tot + 1], SLEWS[end])
slew(tot::AbstractFloat) = slew(Int(floor(tot)))  # Jpp convention, not rounding but casting to int
slew(hit::AbstractHit) = slew(hit.tot)

const SLEWS = SVector(
    8.01, 7.52, 7.05, 6.59, 6.15, 5.74, 5.33, 4.95, 4.58, 4.22, 3.89, 3.56,
    3.25, 2.95, 2.66, 2.39, 2.12, 1.87, 1.63, 1.40, 1.19, 0.98, 0.78, 0.60,
    0.41, 0.24, 0.07, -0.10, -0.27, -0.43, -0.59, -0.75, -0.91, -1.08,
    -1.24, -1.41, -1.56, -1.71, -1.85, -1.98, -2.11, -2.23, -2.35, -2.47,
    -2.58, -2.69, -2.79, -2.89, -2.99, -3.09, -3.19, -3.28, -3.37, -3.46,
    -3.55, -3.64, -3.72, -3.80, -3.88, -3.96, -4.04, -4.12, -4.20, -4.27,
    -4.35, -4.42, -4.49, -4.56, -4.63, -4.70, -4.77, -4.84, -4.90, -4.97,
    -5.03, -5.10, -5.16, -5.22, -5.28, -5.34, -5.40, -5.46, -5.52, -5.58,
    -5.63, -5.69, -5.74, -5.80, -5.85, -5.91, -5.96, -6.01, -6.06, -6.11,
    -6.16, -6.21, -6.26, -6.31, -6.36, -6.41, -6.45, -6.50, -6.55, -6.59,
    -6.64, -6.68, -6.72, -6.77, -6.81, -6.85, -6.89, -6.93, -6.98, -7.02,
    -7.06, -7.09, -7.13, -7.17, -7.21, -7.25, -7.28, -7.32, -7.36, -7.39,
    -7.43, -7.46, -7.50, -7.53, -7.57, -7.60, -7.63, -7.66, -7.70, -7.73,
    -7.76, -7.79, -7.82, -7.85, -7.88, -7.91, -7.94, -7.97, -7.99, -8.02,
    -8.05, -8.07, -8.10, -8.13, -8.15, -8.18, -8.20, -8.23, -8.25, -8.28,
    -8.30, -8.32, -8.34, -8.37, -8.39, -8.41, -8.43, -8.45, -8.47, -8.49,
    -8.51, -8.53, -8.55, -8.57, -8.59, -8.61, -8.62, -8.64, -8.66, -8.67,
    -8.69, -8.70, -8.72, -8.74, -8.75, -8.76, -8.78, -8.79, -8.81, -8.82,
    -8.83, -8.84, -8.86, -8.87, -8.88, -8.89, -8.90, -8.92, -8.93, -8.94,
    -8.95, -8.96, -8.97, -8.98, -9.00, -9.01, -9.02, -9.04, -9.04, -9.04,
    -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04,
    -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04,
    -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04,
    -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04,
    -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04,
    -9.04, -9.04
)

"""
Get the time of a hit with a rise time (slew) correction.
"""
@inline function Base.time(h::AbstractHit; correct_slew=true)
    correct_slew && return h.t - slew(h.tot)
    h.t
end


"""

The acoustics fit results of the dynamic calibration. The parameters describe
the shape of a string using the mechanical model.

"""
struct AcousticsFit
    id::Int       #  string identifier
    tx::Float64   #  slope dx/dz
    ty::Float64   #  slope dy/dz
    tx2::Float64  #  2nd order correction of slope dx/dz
    ty2::Float64  #  2nd order correction of slope dy/dz
    vs::Float64   #  stretching factor
end

struct DynamicPositionHeader
    detid::Int
    timestart::Float64
    timestop::Float64
    ndf::Float64
    npar::Int
    nhit::Int
    chi2::Float64
    numberOfIterations::Int
    nfit::Int
end


"""
A container type to store and access dynamic calibration results conveniently.
"""
struct DynamicPosition
    header::DynamicPositionHeader
    fits::Vector{AcousticsFit}
end

struct DynamicPositionSet
    calibrations::Vector{DynamicPosition}
end

function Base.show(io::IO, s::DynamicPositionSet)
    timestart = unix2datetime(minimum(s.header.timestart for s in s.calibrations))
    timestop = unix2datetime(maximum(s.header.timestop for s in s.calibrations))
    print(io, "DynamicPositionSet ($timestart - $timestop)")
end


"""
A single orientation measurement from a DOM compass, storing the quaternion
orientation (a, b, c, d correspond to q0, qx, qy, qz) and the timestamp.
"""
struct OrientationFit
    id::Int32        # module identifier
    t::Float64       # UNIX time [s]
    ns::UInt64       # sub-second nanoseconds
    q::Quaternion{Float64}  # orientation quaternion
    policy::Bool
end
