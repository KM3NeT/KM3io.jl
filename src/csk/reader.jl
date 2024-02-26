# 
# CSK (CLB Swiss Knife) Data Format(s)
#

struct Reader
    io::IO
    size::Int64

    function Reader(io::IO)
        pos = position(io)
        seekend(io)
        size = position(io)
        seek(io, pos)
        return new(io, size)
    end
end

struct ReaderState
    pos::Int64
    info::Union{Nothing,CLBInfoWord}
end

Base.eltype(::Type{Reader}) = CLBDatagram

# having a default different from nothing to be able to compare with e.g. piezo_mini which 
# harcode those values.
DEFAULT_INFOWORD = CLBInfoWord(176,25,0)

function Base.iterate(csk::Reader, state::ReaderState=ReaderState(0, DEFAULT_INFOWORD))
    if state.pos > 8972*4
        # FIXME: this is just for debug, remove it !
        return nothing
    end
    if state.pos >= csk.size
        return nothing
    end
    seek(csk.io, state.pos)
    dg = read(csk.io, CLBDatagram)
    if dg.header.data_type == value(CLBAcousticData)
        has_info_word = dg.header.udp_sequence_number == 0
        if (has_info_word)
            buffer = IOBuffer(dg.payload[1:48])
            info = read(buffer, CLBInfoWord)
            dg = dg2acoustic(dg, info, true)
        else
            if state.info !== nothing
                dg = dg2acoustic(dg, state.info, false)
            end
        end
    else
        error("PMT or monitoring data decoding not yet implemented")
    end

    return (dg, ReaderState(state.pos + dg.size + 4, has_info_word ? info : state.info))
end

function Base.read(io::IO, ::Type{T}) where {T<:CLBCommonHeader}
    data_type = ntoh(read(io, UInt32))
    data_types = (value(CLBAcousticData), value(CLBMonitoringData), value(CLBPMTData))
    if data_type ∉ data_types
        error("data type $data_type is unknown")
    end
    run_number = ntoh(read(io, UInt32))
    udp_sequence_number = ntoh(read(io, UInt32))
    seconds = ntoh(read(io, UInt32))
    ns = ntoh(read(io, UInt32))
    dom_id = ntoh(read(io, UInt32))
    dom_status1 = ntoh(read(io, UInt32))
    dom_status2 = ntoh(read(io, UInt32))
    dom_status3 = ntoh(read(io, UInt32))
    dom_status4 = ntoh(read(io, UInt32))
    return T(;
        data_type=data_type,
        run_number=run_number,
        s=seconds,
        ns=ns,
        udp_sequence_number=udp_sequence_number,
        dom_id=dom_id,
        dom_status1=dom_status1,
        dom_status2=dom_status2,
        dom_status3=dom_status3,
        dom_status4=dom_status4,
    )
end

function Base.read(io::IO, ::Type{T}) where {T<:CLBInfoWord}
    head = read(io, UInt8)
    sampling_rate = read(io, UInt8)
    ns = ntoh(read(io, UInt32))
    return T(head, sampling_rate, ns)
end

# function decodeaudio(
#     info::CLBInfoWord, buffer::Vector{UInt16}
# )::Vector{AbstractCLBAudioWord}
#     return []
# end

function Base.read(io::IO, ::Type{T}) where {T<:AbstractCLBDatagram}
    size = read(io, UInt32)
    header = read(io, CLBCommonHeader)
    payload = Vector{UInt8}(undef, trunc(Int, size - sizeof(CLBCommonHeader)))
    read!(io, payload)
    payload = ntoh.(payload)
    return CLBDatagram(; size=size, header=header, payload=payload)
end
