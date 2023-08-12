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

Return `true` if the TDC is in high rate veto.

"""
hrvstatus(f::SummaryFrame, tdc) = nthbitset(tdc, f.status)

"""

Return `true` if any of the TDCs is in high rate veto.

"""
hrvstatus(f::SummaryFrame) = (f.status << 1) != 0

"""

Return `true` if TDC status is OK.

"""
tdcstatus(f::SummaryFrame) = !hrvstatus(f)

"""

Return `true` if White Rabbit status is OK.

"""
wrstatus(f::SummaryFrame) = nthbitset(31, f.status)

"""

Return `true` if the TDC has FIFO almost full.

"""
fifostatus(f::SummaryFrame, tdc) = nthbitset(tdc, f.fifo)

"""

Return `true` if any of the TDCs is in high rate veto.

"""
fifostatus(f::SummaryFrame) = (f.fifo << 1) != 0

"""

Return `true` if the UDP trailer is present.

"""
hasudptrailer(f::SummaryFrame) = nthbitset(31, f.fifo)

"""

Number of TDCs without high rate veto or FIFO almost full.

"""
function count_active_channels(f::SummaryFrame)
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
function count_fifostatus(f::SummaryFrame)
    n = KM3io.Constants.NUMBER_OF_PMTS
    !fifostatus(f) && return n
    for pmt ∈ 0:(KM3io.Constants.NUMBER_OF_PMTS - 1)
        if fifostatus(f, pmt)
            n -= 1
        end
    end
    n
end

"""

Number of TDCs with high rate veto.

"""
function count_fifostatus(f::SummaryFrame)
    n = KM3io.Constants.NUMBER_OF_PMTS
    !hrvstatus(f) && return n
    for pmt ∈ 0:(KM3io.Constants.NUMBER_OF_PMTS - 1)
        if hrvstatus(f, pmt)
            n -= 1
        end
    end
    n
end
