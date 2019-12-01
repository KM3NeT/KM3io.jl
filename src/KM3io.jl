module KM3io

using Corpuscles

abstract type AbstractHit end

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

struct Event
    hits::Vector{AbstractHit}
end
Event() = Event(Vector{AbstractHit}())

struct EvtFile
    events::Dict{T, Event} where {T <: Integer}
end

EvtFile() = EvtFile(Dict{Int64, Event}())

function read_hit_entry(line::AbstractString)
    fields = split(line)
    id = parse(Int64, fields[2])
    pmt_id = parse(Int64, fields[3])
    npe = parse(Float64, fields[4])
    time = parse(Float64, fields[5])
    geantid = GeantID(parse(Int64, fields[6]))
    track_id = parse(Int64, fields[7])
    Hit(id, pmt_id, npe, time, geantid, track_id)
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
                    hit = read_hit_entry(line)
                    push!(event.hits, hit)
                end
            end
        end
    end
    return evtfile
end 

EvtFile(filepath::AbstractString) = read_evt_file(filepath)

end # module
