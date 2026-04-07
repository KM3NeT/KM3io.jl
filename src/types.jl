"""

A simple quaternion derived from a `FieldVector` of StaticArrays, no more, no less.

"""
struct Quaternion{T} <: FieldVector{4, T}
    q0::T
    qx::T
    qy::T
    qz::T
end

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

struct DateRange
    from::DateTime
    to::DateTime
end

abstract type AbstractHit end
abstract type AbstractDAQHit<:AbstractHit end
abstract type AbstractMCHit<:AbstractHit end
abstract type AbstractCalibratedHit <: AbstractDAQHit end
abstract type AbstractCalibratedMCHit <: AbstractMCHit end

"""

A snapshot hit.

"""
struct SnapshotHit <: AbstractDAQHit
    dom_id::UInt32
    channel_id::UInt8
    t::Int32
    tot::UInt8
end

"""

A calibrated snapshot hit.

"""
struct CalibratedSnapshotHit <: AbstractCalibratedHit
    dom_id::UInt32
    channel_id::UInt8
    t::Float64
    tot::UInt8
end

"""

A hit which was triggered.

"""
struct TriggeredHit <: AbstractDAQHit
    dom_id::Int32
    channel_id::UInt8
    t::Int32
    tot::UInt8
    trigger_mask::UInt64
end

"""

A calibrated triggered hit.

"""
struct CalibratedTriggeredHit <: AbstractCalibratedHit
    dom_id::UInt32
    channel_id::UInt8
    t::Float64
    tot::UInt8
    trigger_mask::UInt64
end


"""

A fully dressed hit with all calibration information which can be
obtained. This structure is similar to the Hit structure in aanet
and should be used wisely. Most of the time it's much more
performant to use dedicated (simplified) structures.

"""
struct XCalibratedHit <: AbstractCalibratedHit
    dom_id::UInt32
    channel_id::UInt32
    t::Float64
    tot::UInt8
    trigger_mask::UInt64
    pos::Position{Float64}
    dir::Direction{Float64}
    t0::Float64
    string::UInt8
    floor::UInt8
end

abstract type AbstractUTCTime end

"""

A basic time structure with seconds and nanoseconds. The seconds are counting
from the start of the epoch, just like the UNIX time.

"""
struct UTCTime <: AbstractUTCTime
    s::Int64
    ns::Int64
end
Base.show(io::IO, t::UTCTime) = print(io, "$(typeof(t))($(t.s), $(t.ns))")

"""

An extended time structure used in the DAQ. It contains the White Rabbit time
synchronisation status. `wr_status == 0` means that the synchronisation is OK.

"""
struct UTCExtended <: AbstractUTCTime
    s::UInt32
    ns::UInt32
    wr_status::Int

    function UTCExtended(seconds, ns_cycles)
        wr_status = (seconds >> 31) & 1
        s = seconds & 0x7FFFFFFF  # skipping the most significant bit
        new(s, ns_cycles * 16, wr_status)
    end
end
Base.show(io::IO, t::UTCExtended) = print(io, "$(typeof(t))($(signed(t.s)), $(signed(t.ns)), $(t.wr_status))")

Base.convert(::Type{DateTime}, utc::AbstractUTCTime) = unix2datetime(utc.s + utc.ns * 1e-9)

Base.isless(a::AbstractUTCTime, b::AbstractUTCTime) = a.s < b.s || (a.s == b.s && a.ns < b.ns)
Base.:(==)(a::AbstractUTCTime, b::AbstractUTCTime) = a.s == b.s && a.ns == b.ns

"""

A `SummaryFrame` contains reduced timeslice data from an optical module.

The PMT `rates` are encoded as single bytes and can be converted to real
hit rates using the `rates(s::SummaryFrame)` function.

"""
struct SummaryFrame
    dom_id::Int32
    daq::UInt32
    status::UInt32  # contais HRV
    fifo::UInt32
    status3::UInt32
    status4::UInt32
    rates::SVector{31, UInt8}
end

"""

The header of a summaryslice.

"""
struct SummarysliceHeader
    detector_id::Int32
    run::Int32
    frame_index::Int32
    t::UTCExtended
end

"""

The header of an event.

"""
struct EventHeader
    detector_id::Int32
    run::Int32
    frame_index::Int32
    t::UTCExtended
    trigger_counter::UInt64
    trigger_mask::UInt64
    overlays::UInt32
end

"""

A (triggered) event holding snapshot hits and triggered hits. The triggered hits
are a subset of the snapshot hits.

"""
struct DAQEvent
    header::EventHeader
    snapshot_hits::Vector{SnapshotHit}
    triggered_hits::Vector{TriggeredHit}
end
