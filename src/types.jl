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
