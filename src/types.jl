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

abstract type AbstractHit end
abstract type AbstractDAQHit<:AbstractHit end
abstract type AbstractMCHit<:AbstractHit end

struct SnapshotHit <: AbstractDAQHit
    channel_id::UInt8
    dom_id::UInt32
    t::Float64
    tot::UInt8
    trigger_mask::Int64
end

struct TriggeredHit <: AbstractDAQHit
    dom_id::Int32
    channel_id::UInt8
    t::Int32
    tot::UInt8
    trigger_mask::Int64
end

struct DAQEvent
    det_id::Int32
    run_id::Int32
    timeslice_id::Int32
    timestamp::Int32
    ticks::Int32
    trigger_counter::Int64
    trigger_mask::Int64
    overlays::Int32
    n_triggered_hits::Int32
    triggered_hits::Vector{TriggeredHit}
    n_snapshot_hits::Int32
    snapshot_hits::Vector{SnapshotHit}
end

Base.show(io::IO, d::DAQEvent) = begin
    print(io, "DAQEvent: $(d.n_triggered_hits) triggered hits, " *
              "$(d.n_snapshot_hits) snapshot hits")
end
