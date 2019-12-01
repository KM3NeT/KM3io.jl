module KM3io

using StaticArrays
using Corpuscles

abstract type AbstractHit end

struct Cartesian{T} <: FieldVector{3, T}
    x::T
    y::T
    z::T
end

struct RawHit <: AbstractHit
    id::Integer
    PMid::Integer
    pe::Integer
    time::Integer
end

struct Hit <: AbstractHit
    id::Integer
    PMid::Integer
    npe::Real
    time::Real
    particle::GeantID
    track_id::Integer
end

struct KineticInfo
    vtx_pos::Cartesian{T} where {T <: Real}
    dir::Cartesian{T} where {T <: Real}
    energy::Real
    time::Real
end

struct Neutrino
    id::Integer
    kin::KineticInfo
    bjorken::Tuple{Real, Real}
    ichannel::Integer
    particle::PDGID
    cc::Bool
end

struct Track
    id::Integer
    kin::KineticInfo
    particle::GeantID
end

struct Event
    hits::Vector{AbstractHit}
    neutrinos::Vector{Neutrino}
    tracks::Vector{Track}
end
Event() = Event(Vector{AbstractHit}(), Vector{Neutrino}(), Vector{Track}())

struct EvtFile
    events::Dict{T, Event} where {T <: Integer}
end

EvtFile() = EvtFile(Dict{Int64, Event}())

function read_evt_hit(line::AbstractString)
    fields = split(line)
    id = parse(Int64, fields[2])
    pmt_id = parse(Int64, fields[3])
    npe = parse(Float64, fields[4])
    time = parse(Float64, fields[5])
    geantid = GeantID(parse(Int64, fields[6]))
    track_id = parse(Int64, fields[7])
    Hit(id, pmt_id, npe, time, geantid, track_id)
end

function parse_kin(fields::Vector{T}) where {T <: AbstractString}
    x = parse(Float64, fields[1])
    y = parse(Float64, fields[2])
    z = parse(Float64, fields[3])
    pos = Cartesian(x, y, z)
    vx = parse(Float64, fields[4])
    vy = parse(Float64, fields[5])
    vz = parse(Float64, fields[6])
    dir = Cartesian(vx, vy, vz)
    energy = parse(Float64, fields[7])
    time = parse(Float64, fields[8])
    KineticInfo(pos, dir, energy, time)
end

function read_evt_neutrino(line::AbstractString)
    fields = split(line)
    id = parse(Int64, fields[2])
    kin = parse_kin(String.(fields[3:10]))
    bjorken_x = parse(Float64, fields[11])
    bjorken_y = parse(Float64, fields[12])
    bjorken = (bjorken_x, bjorken_y)
    ichan = parse(Int8, fields[13])
    particle = PDGID(parse(Int8, fields[14]))
    cc = ( parse(Int8, fields[15]) == 2 )
    Neutrino(id, kin, bjorken, ichan, particle, cc)
end

function read_evt_track(line::AbstractString)
    fields = split(line)
    id = parse(Int64, fields[2])
    kin = parse_kin(fields[3:10])
    particle = GeantID(parse(Int8, fields[11]))
    Track(id, kin, particle)
end

function read_evt_file(filepath::AbstractString)
    f = open(filepath)
    evtfile = EvtFile()
    while !eof(f)
        line = readline(f)
        if occursin("start_event:", line)
            fields = split(line)
            eventid = parse(Int64, fields[2])
            event = Event()
            evtfile.events[eventid] = event
            while !occursin("end_event:", line)
                line = readline(f)
                if occursin("hit:", line)
                    hit = read_evt_hit(line)
                    push!(event.hits, hit)
                elseif occursin("neutrino:", line)
                    neutrino = read_evt_neutrino(line)
                    push!(event.neutrinos, neutrino)
                elseif occursin("track_in:", line)
                    track = read_evt_track(line)
                    push!(event.tracks, track)
                end
            end
        end
    end
    return evtfile
end 

EvtFile(filepath::AbstractString) = read_evt_file(filepath)

end # module
