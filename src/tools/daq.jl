function _pmtrate(r::UInt8)
    r == 0 && return 0.0
    Constants.MINIMAL_RATE_HZ * exp(r * Constants.RATE_FACTOR)
end
const RATES = @SArray [_pmtrate(UInt8(r)) for r ∈ 0:255]
"""

Calculate the PMT hit rate from the raw byte stored in a summary frame.

The rate of each PMT is encoded in a single byte to reduce the size of the
summary frame, therefore only 256 values are possible which are mapped to an
exponential function. The values are precalculated by the `_getrate()` function
for the best performance.

"""
pmtrate(r::UInt8) = @inbounds RATES[r + 1]
pmtrate(s::SummaryFrame, pmt::Integer) = pmtrate(s.rates[UInt8(pmt) + 1])

"""

Return the actual rates (in Hz) for each PMT in a summary frame.

"""
pmtrates(s::SummaryFrame) = map(pmtrate, s.rates)

"""

Return a dictionary of DOM IDs as keys and PMT rates [Hz] as values
(`Vector{Float64}`).

"""
pmtrates(s::Summaryslice) = Dict(frame.dom_id => pmtrates(frame) for frame ∈ s.frames)


"""

A frame which carries the DAQ status words (`daq`, `status` and `fifo`) of an
optical module: either the [`SummaryFrame`](@ref) of a summaryslice or the
[`SuperFrame`](@ref) of a timeslice. Both derive from the same `JDAQFrameStatus`
in the dataformat, so the status accessors below work on either.

"""
const AbstractDAQFrame = Union{SummaryFrame, SuperFrame}

"""

Return `true` if the TDC is in high rate veto.

"""
hrvstatus(f::AbstractDAQFrame, tdc) = nthbitset(tdc, f.status)

"""

Return `true` if any of the TDCs is in high rate veto.

"""
hrvstatus(f::AbstractDAQFrame) = (f.status << 1) != 0

"""

Return `true` if TDC status is OK.

"""
tdcstatus(f::AbstractDAQFrame) = !hrvstatus(f)

"""

Return `true` if White Rabbit status is OK.

"""
wrstatus(f::AbstractDAQFrame) = nthbitset(31, f.status)

"""

Return `true` if the TDC has FIFO almost full.

"""
fifostatus(f::AbstractDAQFrame, tdc) = nthbitset(tdc, f.fifo)

"""

Return `true` if any of the TDCs is in high rate veto.

"""
fifostatus(f::AbstractDAQFrame) = (f.fifo << 1) != 0

"""

Return `true` if the UDP trailer is present.

"""
hasudptrailer(f::AbstractDAQFrame) = nthbitset(31, f.fifo)

"""

Number of TDCs without high rate veto or FIFO almost full.

"""
function count_active_channels(f::AbstractDAQFrame)
    n = KM3io.Constants.NUMBER_OF_PMTS
    !hrvstatus(f) && !fifostatus(f) && return n
    for pmt ∈ 0:(KM3io.Constants.NUMBER_OF_PMTS - 1)
        if hrvstatus(f, pmt) || fifostatus(f, pmt)
            n -= 1
        end
    end
    n
end

"""

Number of TDCs with FIFO almost full.

"""
function count_fifostatus(f::AbstractDAQFrame)
    !fifostatus(f) && return 0
    n = 0
    for pmt ∈ 0:(KM3io.Constants.NUMBER_OF_PMTS - 1)
        if fifostatus(f, pmt)
            n += 1
        end
    end
    n
end

"""

Number of TDCs with high rate veto.

"""
function count_hrvstatus(f::AbstractDAQFrame)
    !hrvstatus(f) && return 0
    n = 0
    for pmt ∈ 0:(KM3io.Constants.NUMBER_OF_PMTS - 1)
        if hrvstatus(f, pmt)
            n += 1
        end
    end
    n
end

"""

Return `true` if TDC and White Rabbit status are OK.

"""
status(f::AbstractDAQFrame) = wrstatus(f) && tdcstatus(f)


"""

Maximal sequence number of all received UDP packets.

"""
maximal_udp_sequence_number(f::AbstractDAQFrame) = signed(f.daq >> 16)

"""

Number of received UDP packets (excluding the trailer).

"""
number_of_udp_packets_received(f::AbstractDAQFrame) = signed(f.daq & 0x0000FFFF)

"""

Return `true` if the data of the frame was completely received, i.e. all UDP
packets arrived and the trailer is present.

"""
testdaqstatus(f::AbstractDAQFrame) =
    number_of_udp_packets_received(f) == maximal_udp_sequence_number(f) + 1 && hasudptrailer(f)


"""

The defects which the data filter checks the raw data of a super frame for. The
names in parentheses are the corresponding error types of Jpp's `JChecksum`.

- `PMT_ERROR` (`EPMT_t`): a hit with an out-of-range PMT channel
- `TDC_ERROR` (`ETDC_t`): a hit with a time beyond the duration of the frame
- `TIME_ERROR` (`TIME_t`): hit times which are not monotonically increasing within a PMT
- `UDP_ERROR` (`EUDP_t`): an incomplete UDP transfer (lost packets or a missing trailer)

"""
@enum DAQFrameError PMT_ERROR TDC_ERROR TIME_ERROR UDP_ERROR

# Jpp's `JChecksum` additionally knows a `SIZE_t` defect (too many hits), which is
# disabled in the data filter (the maximal frame size is set to the largest
# representable integer), so it is not checked here.
const _MAXIMAL_TDC = round(UInt32, 1.05 * Constants.FRAME_TIME)  # [ns], with the 5% margin of Jpp

"""

Check the raw data of a super frame and return the defects found, which is the
same check (`JChecksum`) the data filter applies when it decides whether to
accept a frame. Frames of the `:TS` stream (the bare `KM3NET_TIMESLICE` tree) are
exactly those which failed it, so this tells why they were discarded. Which
defects occur in a file depends on the data filter configuration of the run.

Returns an empty vector for an intact frame, see also `isvalid`.

"""
function checksum(f::SuperFrame)
    errors = DAQFrameError[]
    testdaqstatus(f) || push!(errors, UDP_ERROR)
    t = zeros(UInt32, Constants.NUMBER_OF_PMTS)  # last hit time of each PMT
    for hit ∈ f.hits
        if hit.channel_id >= Constants.NUMBER_OF_PMTS
            PMT_ERROR ∈ errors || push!(errors, PMT_ERROR)
            continue
        end
        # the hit time is the raw TDC value, which is unsigned in the dataformat;
        # a corrupt one can exceed the range of the signed field it is stored in
        tdc = reinterpret(UInt32, hit.t)
        if tdc > _MAXIMAL_TDC
            TDC_ERROR ∈ errors || push!(errors, TDC_ERROR)
        end
        pmt = hit.channel_id + 1
        if tdc < t[pmt]
            TIME_ERROR ∈ errors || push!(errors, TIME_ERROR)
        end
        t[pmt] = tdc
    end
    sort!(errors)
end

"""

Return `true` if the raw data of the super frame has no defects, see
[`checksum`](@ref).

"""
Base.isvalid(f::SuperFrame) = isempty(checksum(f))
