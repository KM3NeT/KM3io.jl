struct UTMPosition{T} <: FieldVector{3, T}
    east::T
    north::T
    z::T
end

struct Position{T} <: FieldVector{3, T}
    x::T
    y::T
    z::T
end

struct Direction{T} <: FieldVector{3, T}
    x::T
    y::T
    z::T
end
Direction(ϕ, θ) = Direction(cos(ϕ)*sin(θ), sin(ϕ)*sin(θ), cos(θ))

struct Quaternion{T} <: FieldVector{4, T}
    q0::T
    qx::T
    qy::T
    qz::T
end

struct DateRange
    from::DateTime
    to::DateTime
end
