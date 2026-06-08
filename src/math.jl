"""
Hamilton product of two quaternions.
"""
function ⊗(q1::Quaternion, q2::Quaternion)
    Quaternion(
        q1.q0*q2.q0 - q1.qx*q2.qx - q1.qy*q2.qy - q1.qz*q2.qz,
        q1.q0*q2.qx + q1.qx*q2.q0 + q1.qy*q2.qz - q1.qz*q2.qy,
        q1.q0*q2.qy - q1.qx*q2.qz + q1.qy*q2.q0 + q1.qz*q2.qx,
        q1.q0*q2.qz + q1.qx*q2.qy - q1.qy*q2.qx + q1.qz*q2.q0,
    )
end

"""
Quaternion conjugate (negates the imaginary components).
"""
Base.conj(q::Quaternion) = Quaternion(q.q0, -q.qx, -q.qy, -q.qz)

"""
Convert a 3×3 rotation matrix to a `Quaternion` using the Shepperd method.
"""
function rotation_matrix_to_quaternion(R::AbstractMatrix)
    trace = R[1,1] + R[2,2] + R[3,3]
    if trace > 0
        s = sqrt(trace + 1.0) * 2            # s = 4*q0
        Quaternion(0.25 * s,
                   (R[3,2] - R[2,3]) / s,
                   (R[1,3] - R[3,1]) / s,
                   (R[2,1] - R[1,2]) / s)
    elseif R[1,1] > R[2,2] && R[1,1] > R[3,3]
        s = sqrt(1.0 + R[1,1] - R[2,2] - R[3,3]) * 2  # s = 4*qx
        Quaternion((R[3,2] - R[2,3]) / s,
                   0.25 * s,
                   (R[1,2] + R[2,1]) / s,
                   (R[1,3] + R[3,1]) / s)
    elseif R[2,2] > R[3,3]
        s = sqrt(1.0 + R[2,2] - R[1,1] - R[3,3]) * 2  # s = 4*qy
        Quaternion((R[1,3] - R[3,1]) / s,
                   (R[1,2] + R[2,1]) / s,
                   0.25 * s,
                   (R[2,3] + R[3,2]) / s)
    else
        s = sqrt(1.0 + R[3,3] - R[1,1] - R[2,2]) * 2  # s = 4*qz
        Quaternion((R[2,1] - R[1,2]) / s,
                   (R[1,3] + R[3,1]) / s,
                   (R[2,3] + R[3,2]) / s,
                   0.25 * s)
    end
end

"""

Interpolate between two vectors (e.g. quaternions) using the slerp method. `t`
should be between 0 and 1. 0 will produce `q₁` and `1` `q₂`.

The input vectors `q₁` and `q₂` will be normalised unless `normalized` is
`false`. It is not done by default to shave off a few dozens of nanoseconds.
Make sure to set `normalized=false` if the input vectors are not unit vectors.

"""
function slerp(q₁, q₂, t::Real; dot_threshold=0.9995, normalized=true)
    if !normalized
        q₁ = normalize(q₁)
        q₂ = normalize(q₂)
    end

    dot = q₁⋅q₂

    if (dot < 0.0)
	    q₂ *= -1
	    dot = -dot
    end

    s₁ = t
    s₀ = 1.0 - t

    if dot <= dot_threshold
        θ₀ = acos(dot)
        θ₁ = θ₀ * t

        s₁ = sin(θ₁) / sin(θ₀)
        s₀ = cos(θ₁) - dot * s₁
    end

    normalize((s₀ * q₁)  +  (s₁ * q₂))
end

# Another implementation which yields slightly different results.
# Further reading: http://number-none.com/product/Understanding%20Slerp,%20Then%20Not%20Using%20It/
#
# function slerp(q₁, q₂, t::Real; dot_threshold=0.9995)
#     dot = acos(q₁⋅q₂)
#     dot > dot_threshold && return normalize(q₁ + t*(q₂ - q₁))
#     dot = clamp(dot, -1, 1)
#     θ = acos(dot) * t
#     q = normalize(q₂ - q₁*dot)
#     q₁*cos(θ) + q*sin(θ)
# end

"""
A compass with yaw, pitch and roll.
"""
struct Compass{T} <: FieldVector{3, T}
    yaw::T
    pitch::T
    roll::T
end

"""

Initialises a [`Compass`](@ref) from a [`Quaternion`](@ref).

"""
function Compass(q::Quaternion)
    yaw = -atan(2.0 * (q.q0 * q.qz + q.qx * q.qy), 1.0 - 2.0 * (q.qy * q.qy + q.qz * q.qz))
    sp = 2.0 * (q.q0 * q.qy - q.qz * q.qx)

    if (sp >= +1.0)
        pitch = asin(+1.0)
    elseif (sp <= -1.0)
        pitch = asin(-1.0)
    else
        pitch = asin(sp)
    end

    roll = -atan(2.0 * (q.q0 * q.qx + q.qy * q.qz), 1.0 - 2.0 * (q.qx * q.qx + q.qy * q.qy))

    Compass(yaw, pitch, roll)
end

Quaternion(c::Compass) = Quaternion(c.yaw, c.pitch, c.roll)

function Quaternion(yaw, pitch, roll)
    cr = cos(-roll*0.5)
    sr = sin(-roll*0.5)
    cp = cos(pitch*0.5)
    sp = sin(pitch*0.5)
    cy = cos(-yaw*0.5)
    sy = sin(-yaw*0.5)

    Quaternion(
        cr * cp * cy + sr * sp * sy,
        sr * cp * cy - cr * sp * sy,
        cr * sp * cy + sr * cp * sy,
        cr * cp * sy - sr * sp * cy
    )
end

"""
    correct(c::Compass, declination::Real, meridian::Real) -> Compass

Apply magnetic declination and meridian convergence corrections to a compass
measurement, mirroring Jpp's `JCompass::correct(declination, meridian)`.

`declination` and `meridian` must be in **radians**.

Jpp stores yaw in the nautical (z-down, North-to-East) frame and applies:
    yaw -= declination;  yaw += meridian
KM3io's `Compass.yaw` is the negation of Jpp's yaw (KM3NeT z-up frame), so
the equivalent correction is:
    yaw += declination - meridian

See also [`orca_magnetic_declination`](@ref), [`arca_magnetic_declination`](@ref),
[`ORCA_MERIDIAN_CONVERGENCE_ANGLE_RAD`](@ref), [`ARCA_MERIDIAN_CONVERGENCE_ANGLE_RAD`](@ref).
"""
correct(c::Compass, declination::Real, meridian::Real) =
    Compass(c.yaw + declination - meridian, c.pitch, c.roll)

"""
    correct(q::Quaternion, declination::Real, meridian::Real) -> Quaternion

Apply magnetic declination and meridian convergence corrections directly to an
orientation quaternion. Equivalent to converting to [`Compass`](@ref), calling
[`correct`](@ref), and converting back.

`declination` and `meridian` must be in **radians**.
"""
function correct(q::Quaternion, declination::Real, meridian::Real)
    Δyaw = declination - meridian
    Quaternion(Δyaw, 0.0, 0.0) ⊗ q
end
