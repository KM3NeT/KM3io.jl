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
    dom_id::UInt32
    channel_id::UInt8
    t::Int32
    tot::UInt8
end

struct TriggeredHit <: AbstractDAQHit
    dom_id::Int32
    channel_id::UInt8
    t::Int32
    tot::UInt8
    trigger_mask::UInt64
end

struct UTCExtended
    s::UInt32
    ns::UInt32
    wr_status::Bool

    function UTCExtended(seconds, ns_cycles)
        wr_status = seconds & 0x80000000  # most significant bit indicates White Rabbit status
        s = seconds & 0x7FFFFFFF  # skipping the most significant bit
        new(s, ns_cycles * 16, wr_status)
    end
end

struct EventHeader
    detector_id::Int32
    run::Int32
    frame_index::Int32
    t::UTCExtended
    trigger_counter::UInt64
    trigger_mask::UInt64
    overlays::UInt32
end

struct DAQEvent
    header::EventHeader
    snapshot_hits::Vector{SnapshotHit}
    triggered_hits::Vector{TriggeredHit}
end
