
abstract type AbstractCLBDatagram end
abstract type AbstractCLBAcousticDatagram <: AbstractCLBDatagram end
abstract type AbstractCLBPMTDatagram <: AbstractCLBDatagram end
abstract type AbstractCLBMonitoringDatagram <: AbstractCLBDatagram end

abstract type AbstractCLBAudioWord end

# audio words can be of 4 differents bit lengths (multiple of 16 bits)
abstract type AbstractCLBAudioWord16 <: AbstractCLBAudioWord end
abstract type AbstractCLBAudioWord32 <: AbstractCLBAudioWord end
abstract type AbstractCLBAudioWord48 <: AbstractCLBAudioWord end
abstract type AbstractCLBAudioWord64 <: AbstractCLBAudioWord end

"""
  CLBDatagram <: AbstractCLBDatagram

Type that represents a generic UDP Datagram coming from the CLB.

### Fields

- `size` -- the total size, in bytes, of this datagram (not counting the 4 bytes of this size field itself)
- `header` -- the CLB Common header
- `payload` -- a vector of bytes representing the data of this Datagram
"""
Base.@kwdef struct CLBDatagram <: AbstractCLBDatagram
    size::UInt32
    header::CLBCommonHeader
    payload::Vector{UInt8}
end

function Base.show(io::IO, dg::CLBDatagram)
    return print(io, "CLBDatagram of size $(dg.size)", dg.header)
end

function Base.show(io::IO, mime::MIME"text/plain", dg::CLBDatagram)
    println(io, "CLBDatagram")
    println(io, "Size of the datagram: $(dg.size)")
    return display(mime, dg.header)
end

"""
  CLBAcousticDatagram <: AbstractCLBAcousticDatagram

Type that represents a UDP Datagram coming from the CLB acoustic output

### Fields

- `size` -- the total size, in bytes, of this datagram (not counting the 4 bytes of this size field itself)
- `header` -- the CLB Common header
"""
Base.@kwdef struct CLBAcousticDatagram <: AbstractCLBAcousticDatagram
    size::UInt32
    header::CLBCommonHeader
    audio_words::Vector{AbstractCLBAudioWord}
end

function hasinfoword(::AbstractCLBDatagram)
    return false
end

function audiowords(dg::AbstractCLBAcousticDatagram)::Vector{AbstractCLBAcousticDatagram}
    return dg.audio_words
end

"""
  CLBAcousticDatagramWithInfo

Type that represents a UDP Datagram coming from the CLB acoustic output, and containing a special information word.

### Fields

- `info` -- the info word
"""
Base.@kwdef struct CLBAcousticDatagramWithInfo <: AbstractCLBAcousticDatagram
    size::UInt32
    header::CLBCommonHeader
    info::CLBInfoWord
    audio_words::Vector{AbstractCLBAudioWord}
end

function hasinfoword(::CLBAcousticDatagramWithInfo)
    return true
end

function dg2acoustic(dg::CLBDatagram, info::CLBInfoWord, withinfo::Bool)::AbstractCLBAcousticDatagram
    if withinfo == true
        audiowords = extract_audio_words(dg.payload[48:end],info)
        return CLBAcousticDatagramWithInfo(dg.size, dg.header, info, audiowords)
    else
        audiowords = extract_audio_words(dg.payload,info)
        return CLBAcousticDatagram(dg.size, dg.header, audiowords)
    end
end

# function Base.show(io::IO, mime::MIME"text/plain", dg::CLBAcousticDatagramWithInfo)
#     #display(io,mime, convert(::Type{CLBDataGram}, dg))
#     return println(io,"TITI")
# end

function Base.show(io::IO, dg::CLBAcousticDatagramWithInfo)
    dgbase = CLBDatagram(dg.size, dg.header, [])
    return print(io, dgbase, " ", dg.info)
end

function Base.show(io::IO, dg::CLBAcousticDatagram)
    dgbase = CLBDatagram(dg.size, dg.header, [])
    return print(io, dgbase)
end