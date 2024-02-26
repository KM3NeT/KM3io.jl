using Dates

abstract type AbstractCLBDataType end
struct CLBAcousticData <: AbstractCLBDataType end
struct CLBPMTData <: AbstractCLBDataType end
struct CLBMonitoringData <: AbstractCLBDataType end

# TAES=1413563731 (0x54414553 = 'T' 'A' 'E' 'S')
value(::Type{CLBAcousticData})::UInt32 = 1413563731
# TTDC=1414808643 (0x54544443 = 'T' 'T' 'D' 'C')
value(::Type{CLBPMTData})::UInt32 = 1414808643
# TMCH=1414349640 (0x544D4348 = 'T' 'M' 'C' 'H')
value(::Type{CLBMonitoringData})::UInt32 = 414349640

function Base.show(io::IO, v::AbstractCLBDataType)
    bytes = reinterpret(UInt8, [ntoh(value(typeof(v)))])
    s = strip(String(bytes), ['\0'])
    return print(io, s)
end

function NewCLBDataType(word::UInt32)::AbstractCLBDataType
    if word == value(CLBAcousticData)
        CLBAcousticData()
    elseif word == value(CLBPMTData)
        CLBPMTData()
    elseif word == value(CLBMonitoringData)
        CLBMonitoringData()
    else
        error("invalid word $(word) for CLBDataType")
    end
end

"""
  The CLB (Central Logic Board) Common header

### Fields

- `data_type` -- (32 bits) the data type (Acoustic, PMT, Monitoring). Only three possible values are valid for this field.
- `run_number`-- (32 bits) the run number
- `udp_sequence_number` -- (32 bits) the UDP sequence number. Sequence number = 0 generally has some special meaning.
- `s` -- (32 bits) first part of the timestamp of this UDP packet, representing seconds 
- `ns` -- (32 bits) second part of the timestamp of this UPD packet, representing nanoseconds ticks (16ns width) 
- `dom_id` -- (32 bits) optical module (DOM) identifier
- `dom_status1`-- (32 bits) first status word of the DOM
- `dom_status2`-- (32 bits) second status word of the DOM
- `dom_status3`-- (32 bits) third status word of the DOM
- `dom_status4`-- (32 bits) fourth status word of the DOM
"""
Base.@kwdef struct CLBCommonHeader
    data_type::UInt32
    run_number::UInt32
    udp_sequence_number::UInt32
    s::UInt32
    ns::UInt32
    dom_id::UInt32
    dom_status1::UInt32 = 0
    dom_status2::UInt32 = 0
    dom_status3::UInt32 = 0
    dom_status4::UInt32 = 0
end

function Base.show(io::IO, header::CLBCommonHeader)
    print(io, "CLBCommonHeader ", repr(NewCLBDataType(header.data_type)))
    return print(io, " UDPSequenceNumber: $(header.udp_sequence_number)")
end

function Base.show(io::IO, ::MIME"text/plain", header::CLBCommonHeader)
    println(io, "CLBCommonHeader ")
    println("DataType         : ", repr(NewCLBDataType(header.data_type)))
    println("RunNumber        : $(header.run_number)")
    println("UDPSequenceNumber: $(header.udp_sequence_number)")
    println("Timestamp:")
    println(repeat(" ", 10), "Seconds: $(header.s)")
    println(repeat(" ", 10), "Tics:    $(header.ns)")
    d = Dates.unix2datetime(header.s)
    println(repeat(" ", 10), Dates.format(d, "Y u d HH:MM:SS"), " +$(header.ns*16)ns GMT")
    println("DOMIdentifier    : $(header.dom_id)")
    println("DOMStatus 1      : $(header.dom_status1)")
    println("DOMStatus 2      : $(header.dom_status2)")
    println("DOMStatus 3      : $(header.dom_status3)")
    return println("DOMStatus 4      : $(header.dom_status4)")
end

