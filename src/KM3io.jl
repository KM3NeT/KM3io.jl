module KM3io

using StaticArrays
using Corpuscles

import Base: getindex

abstract type AbstractHit end

abstract type DataFile end

struct Cartesian{T} <: FieldVector{3, T}
    x::T
    y::T
    z::T
end

struct NeutrinoWeights{T} <: FieldVector{4, T}
    w1::T
    w2::T
    w3::T
    w4::T
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
    particle::Geant3ID
    track_id::Integer
end

struct KineticInfo
    pos::Cartesian{T} where {T <: Real}
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
    particle::Geant3ID
end

struct Event
    hits::Vector{AbstractHit}
    neutrino::Union{Missing, Neutrino}
    tracks::Vector{Track}
    weights::Union{Missing, NeutrinoWeights}
end
# Event() = Event(Vector{AbstractHit}(), missing, Vector{Track}(), missing)

struct EvtFile <: DataFile
    events::Dict{T, Event} where {T <: Integer}
end

function getindex(f::EvtFile, i::Integer)
    f.events[i]
end

EvtFile() = EvtFile(Dict{Int64, Event}())

function read_evt_hit(line::AbstractString)
    fields = split(line)
    id = parse(Int64, fields[2])
    pmt_id = parse(Int64, fields[3])
    npe = parse(Float64, fields[4])
    time = parse(Float64, fields[5])
    geantid = Geant3ID(parse(Int64, fields[6]))
    track_id = parse(Int64, fields[7])
    Hit(id, pmt_id, npe, time, geantid, track_id)
end

function build_evt_hit_entry(hit::Hit)
    retval =    "hit: $(hit.id) $(hit.PMid) $(hit.npe) "
    retval *=   "$(hit.time) $(hit.particle.value) $(hit.track_id) \n"
    return retval
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

function build_evt_nu_entry(nu::Neutrino)
    retval =    "neutrino: $(nu.id) "
    retval *=   "$(nu.kin.pos.x) $(nu.kin.pos.y) $(nu.kin.pos.z) "
    retval *=   "$(nu.kin.dir.x) $(nu.kin.dir.y) $(nu.kin.dir.z) "
    retval *=   "$(nu.kin.energy) $(nu.kin.time) "
    retval *=   "$(nu.bjorken[1]) $(nu.bjorken[2]) "
    retval *=   "$(nu.ichannel) $(nu.particle.value) $(convert(Int, nu.cc))\n"
    return retval
end

function read_evt_track(line::AbstractString)
    fields = split(line)
    id = parse(Int64, fields[2])
    kin = parse_kin(fields[3:10])
    particle = Geant3ID(parse(Int8, fields[11]))
    Track(id, kin, particle)
end

function build_evt_track_entry(trk::Track)
    retval =    "track_in: $(trk.id) "
    retval *=   "$(trk.kin.pos.x) $(trk.kin.pos.y) $(trk.kin.pos.z) "
    retval *=   "$(trk.kin.dir.x) $(trk.kin.dir.y) $(trk.kin.dir.z) "
    retval *=   "$(trk.kin.energy) $(trk.kin.time) $(trk.particle.value) \n"
    return retval
end

function read_evt_nu_weights(line::AbstractString)
    fields = split(line)
    weights = parse.(Float64, fields[2:4])
    NeutrinoWeights{Float64}(weights..., 0)
end

function read_evt_file(filepath::AbstractString)
    f = open(filepath)
    evtfile = EvtFile()
    while !eof(f)
        line = readline(f)
        if occursin("start_event:", line)
            fields = split(line)
            eventid = parse(Int64, fields[2])
            hits = Vector{AbstractHit}()
            tracks = Vector{Track}()
            neutrino = missing
            weights = missing
            while !occursin("end_event:", line)
                line = readline(f)
                if occursin("hit:", line)
                    hit = read_evt_hit(line)
                    push!(hits, hit)
                elseif occursin("neutrino:", line)
                    neutrino = read_evt_neutrino(line)
                elseif occursin("track_in:", line)
                    track = read_evt_track(line)
                    push!(tracks, track)
                elseif occursin("weights:", line)
                    weights = read_evt_nu_weights(line)
                end
            end
            evtfile.events[eventid] = Event(hits, neutrino, tracks, weights)
        end
    end
    close(f)
    return evtfile
end 

EvtFile(filepath::AbstractString) = read_evt_file(filepath)

extension(url::String) = try match(r"\.[A-Za-z0-9]+$", url).match catch e "" end

function read_compound(files::Vector{T}) where {T <: AbstractString}
    filedata = Dict{AbstractString, DataFile}()
    for filepath in files
        if extension(filepath) == ".evt"
            filedata[filepath] = EvtFile(filepath)
        end
    end
    filedata
end

function write_evt_file(filepath::AbstractString, data::EvtFile)
    f = open(filepath, "w")
    for key in sort(collect(keys(data.events)))
        event = data.events[key]
        write(f, "start_event: $key 1\n")
        for hit in event.hits
            hit_line = build_evt_hit_entry(hit)
            write(f, hit_line)
        end
        write(f, "total_hits: $(length(event.hits))\n")
        for track in event.tracks
            trk_line = build_evt_track_entry(track) 
            write(f, trk_line)
        end
        if !ismissing(event.neutrino)
            nu_line = build_evt_nu_entry(event.neutrino) 
            write(f, nu_line)
        end
        write(f, "end_event: \n")
    end
    close(f)
end

end # module
