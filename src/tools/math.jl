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
