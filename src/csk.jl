# CSK (CLB Swiss Knife) Data Format(s)

function Base.read(io::IO, ::Type{T}) where {T<:CLBCommonHeader}
        data_type = ntoh(read(io, UInt32))
        run_number = ntoh(read(io, UInt32))
        udp_sequence_number = ntoh(read(io, UInt32))
        seconds = ntoh(read(io, UInt32))
        ns = ntoh(read(io, UInt32))
        dom_id = ntoh(read(io, UInt32))
        dom_status1 = ntoh(read(io, UInt32))
        dom_status2 = ntoh(read(io, UInt32))
        dom_status3 = ntoh(read(io, UInt32))
        dom_status4 = ntoh(read(io, UInt32))
        T(data_type=data_type, run_number=run_number,
                s=seconds, ns=ns, udp_sequence_number=udp_sequence_number,
                dom_id=dom_id,
                dom_status1=dom_status1,
                dom_status2=dom_status2,
                dom_status3=dom_status3,
                dom_status4=dom_status4
        )
end

function Base.read(io::IO, ::Type{T}) where {T<:InfoWord}
        head = read(io,UInt8)
        sampling_rate = read(io,UInt8)
        ns = ntoh(read(io,UInt32))
        T(head,sampling_rate,ns)
end

function Base.read(io::IO, ::Type{T}) where {T<:CLBDataGram}
        size = read(io,UInt32)
        header = read(io,CLBCommonHeader)
        has_info_word = header.udp_sequence_number==0
        offsize = sizeof(CLBCommonHeader)
        if (has_info_word) 
                info = read(io,InfoWord)
                offsize += 6
        else
                info = nothing
        end
        payload = Vector{UInt8}(undef,size-offsize)
        read!(io,payload)
        T(size=size,header=header,info=info,payload=payload)
end

function samplingRate(dg::CLBDataGram)
        trunc(Int,1000000 * dg.info.sampling_rate / 128)
end

function amplitudeResolution(dg::CLBDataGram)
  amplitude = (dg.info.head & 0x18) >> 3
  if amplitude == 1 
          16
  elseif amplitude == 2 
          24
  else
    12
  end
end

"""
  Returns the channel(s) this datagram has data for :
  - 2 : channel 2
  - 1 : channel 1
  - 0 : both channels
"""
function channel(dg::CLBDataGram)
  (dg.info.head & 0x60)>>5 
end

