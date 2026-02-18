"""

A simple quaternion derived from a `FieldVector` of StaticArrays, no more, no less.

"""
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

"""

A basic time structure with seconds and nanoseconds. The seconds are counting
from the start of the epoch, just like the UNIX time.

"""
struct UTCTime
    s::Int64
    ns::Int64
end
Base.show(io::IO, t::UTCTime) = print(io, "$(typeof(t))($(t.s), $(t.ns))")

"""

An extended time structure used in the DAQ. It contains the White Rabbit time
synchronisation status. `wr_status == 0` means that the synchronisation is OK.

"""
struct UTCExtended
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
