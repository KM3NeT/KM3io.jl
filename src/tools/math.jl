@inline norm2(d::Direction) = sqrt(foldl(+, abs2.(d)))
@inline unitize(d::Direction) = d ./ norm2(d)

"""
    angle(dir1::T, dir2::T) where {T<:Direction}

Accurately ascertains the undirected angle (0 <= radians < pi)
between two points given in N-dimensional Cartesian coordinates.

Prefer this to `acos` alternatives
- more reliably accurate
- more consistently stable

Suggested when any |coordinate| of either point may be outside 2^±20 or [1/1_000_000, 1_000_000].
Strongly recommended when any |coordinate| is outside 2^±24 or [1/16_000_000, 16_000_000].

If one of the points is at the origin, the result is zero.

The implementation is taken from
[`AngleBetweenVectors.jl`](https://github.com/JeffreySarnoff/AngleBetweenVectors.jl)
and specialised to [`Direction`](@ref) to avoid type piracy.

"""
function angle(dir1::D, dir2::D) where {D<:Direction{T}} where {T}
    unitdir1 = unitize(dir1)
    unitdir2 = unitize(dir2)

    y = unitdir1 .- unitdir2
    x = unitdir1 .+ unitdir2

    a = 2 * atan(norm2(y), norm2(x))

    !(signbit(a) || signbit(float(T)(pi) - a)) ? a : (signbit(a) ? zero(T) : float(T)(pi))
end
Base.angle(t1::Trk, t2::Trk) = angle(t1.dir, t2.dir)
Base.angle(a::T, b::T) where {T<:Union{KM3io.AbstractCalibratedHit, KM3io.PMT}} = angle(a.dir, b.dir)
Base.angle(a, b::Union{KM3io.AbstractCalibratedHit, KM3io.PMT}) = angle(a, b.dir)
Base.angle(a::Union{KM3io.AbstractCalibratedHit, KM3io.PMT}, b) = angle(a.dir, b)

"""

Calculates the disance between two points.

"""
distance(a::Position, b::Position) = norm(a - b)


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
