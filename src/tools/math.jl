"""
Calculate the angle between two vectors.
"""
Base.angle(d1::Direction, d2::Direction) = acos(min(dot(normalize(d1), normalize(d2)), 1))
Base.angle(a::T, b::T) where {T<:Union{KM3io.AbstractCalibratedHit, KM3io.PMT}} = Base.angle(a.dir, b.dir)
Base.angle(a, b::Union{KM3io.AbstractCalibratedHit, KM3io.PMT}) = Base.angle(a, b.dir)
Base.angle(a::Union{KM3io.AbstractCalibratedHit, KM3io.PMT}, b) = Base.angle(a.dir, b)

"""

Calculates the disance between two points.

"""
distance(a::Position, b::Position) = norm(a - b)


"""

Interpolate between two vectors (e.g. quaternions) using the slerp method. `t`
should be between 0 and 1, 0 will produce `q1` and `1` `q2`.

"""
function slerp(q₁, q₂, t::Real; dot_threshold=0.9995)
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
