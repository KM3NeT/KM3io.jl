"""
The photomultiplier tube of an optical module. The `id` stands for the DAQ
channel ID.

A non-zero status means the PMT is "not OK". Individual bits can be read out
to identify the problem (see definitions/pmt_status.jl for the bit positions
and check them using the `nthbitset()` function).

"""
struct PMT
    id::Int32
    pos::Position{Float64}
    dir::Direction{Float64}
    t₀::Float64
    status::Union{Int32, Missing}
end


"""
A module's location in the detector where string represents the
detection unit identifier and floor counts from 0 from the bottom
to top. Base modules are sitting on floor 0 and optical modules
on floor 1 and higher.

"""
struct Location
    string::Int32
    floor::Int8
end
Base.isless(lhs::Location, rhs::Location) = lhs.string < rhs.string && lhs.floor < rhs.floor


"""
Either a base module or an optical module. A non-zero status means the
module is "not OK". Individual bits can be read out to identify the problem (see
definitions/module_status.jl for the bit positions and check them using the
`nthbitset()` function).

"""
struct DetectorModule
    id::Int32
    pos::Position{Float64}
    location::Location
    n_pmts::Int8
    pmts::Vector{PMT}
    q::Union{Quaternion{Float64}, Missing}
    status::Int32
    t₀::Float64
end
function Base.show(io::IO, m::DetectorModule)
    info = m.location.floor == 0 ? "base" : "optical, $(m.n_pmts) PMTs"
    print(io, "Detectormodule ($(info)) on string $(m.location.string) floor $(m.location.floor)")
end
Base.length(d::DetectorModule) = d.n_pmts
Base.eltype(::Type{DetectorModule}) = PMT
Base.iterate(d::DetectorModule, state=1) = state > d.n_pmts ? nothing : (d.pmts[state], state+1)
"""
    Base.getindex(d::DetectorModule, i) = d.pmts[i+1]

The index in this context is the DAQ channel ID of the PMT, which is counting from 0.
"""
Base.getindex(d::DetectorModule, i) = d.pmts[i+1]
isbasemodule(d::DetectorModule) = d.location.floor == 0

"""

Calculate the centre of a module by fitting the crossing point of the PMT axes.

"""
center(m::DetectorModule) = center(m.pmts)

function center(pmts::Vector{PMT})
    x = 0.0
    y = 0.0
    z = 0.0

    V = zeros(Float64, 3, 3)

    for pmt ∈ pmts
          xx = 1.0 - pmt.dir.x * pmt.dir.x
          yy = 1.0 - pmt.dir.y * pmt.dir.y
          zz = 1.0 - pmt.dir.z * pmt.dir.z

          xy = -pmt.dir.x * pmt.dir.z
          xz = -pmt.dir.x * pmt.dir.z
          yz = -pmt.dir.y * pmt.dir.z

          V[1,1] += xx
          V[1,2] += xy
          V[1,3] += xz

          V[2,2] += yy
          V[2,3] += yz

          V[3,3] += zz

          x  +=  xx * pmt.pos.x + xy * pmt.pos.y + xz * pmt.pos.z
          y  +=  xy * pmt.pos.x + yy * pmt.pos.y + yz * pmt.pos.z
          z  +=  xz * pmt.pos.x + yz * pmt.pos.y + zz * pmt.pos.z
    end

    M = inv(Symmetric(V))

    Position(
        M[1,1] * x + M[1,2] * y + M[1,3] * z,
        M[2,1] * x + M[2,2] * y + M[2,3] * z,
        M[3,1] * x + M[3,2] * y + M[3,3] * z,
    )
end

"""
A hydrophone, typically installed in the base module of a KM3NeT detector's
string.
"""
struct Hydrophone
    location::Location
    pos::Position{Float64}
end

"""
    function read(filename::AbstractString, T::Type{Hydrophone})

Reads a vector of `Hydrophone`s from an ASCII file.
"""
function read(filename::AbstractString, T::Type{Hydrophone})
    hydrophones = T[]
    for line ∈ readlines(filename)
        if startswith(line, "#")
            continue
        end
        string, floor, x, y, z = split(line)
        location = Location(parse(Int32, string), parse(Int8, floor))
        pos = Position(parse.(Float64, [x, y, z])...)
        push!(hydrophones, T(location, pos))
    end
    hydrophones
end
"""
A tripod installed on the seabed which sends acoustic signals to modules.
"""
struct Tripod
    id::Int8
    pos::Position{Float64}
end
"""
    function read(filename:AbstractString, T::Type{Tripod})

Reads a vector of `Tripod`s from an ASCII file.
"""
function read(filename::AbstractString, T::Type{Tripod})
    tripods = T[]
    for line ∈ readlines(filename)
        if startswith(line, "#")
            continue
        end
        id, x, y, z = split(line)
        id = parse(Int8, id)
        pos = Position(parse.(Float64, [x, y, z])...)
        push!(tripods, T(id, pos))
    end
    tripods
end
"""
    function write(filename::AbstractString, tripods::Dict{Int8, Tripod})

Writes the position of tripods out into an ASCII file.
"""
function write(filename::AbstractString, tripods::Vector{Tripod})
    open(filename, "a") do file
        write(file, "# Precalibrated autonomous acoustic beacon locations.\n")
        for tripod in tripods
            pos = round.(tripod.pos, digits=3)
            if tripod.id < 10
                @printf(file, "%i    +%1.3f  +%1.3f  %1.3f\n", tripod.id, pos.x, pos.y, pos.z)
                # write(file, @sprintf "%i    +%1.3f  +%1.3f  %1.3f\n" tripod.id pos.x pos.y pos.z)
            elseif tripod.id > 9 && tripod.id < 100
                @printf(file, "%i   +%1.3f  +%1.3f  %1.3f\n", tripod.id, pos.x, pos.y, pos.z)
            end
        end
    end
end
"""
Waveform translates Emitter ID to Tripod ID.
"""
struct Waveform
    ids::Dict{Int8, Int8}
end
"""
    function read(filename::AbstractString, T::Type{Waveform})

Reads the waveform ASCII file.
"""
function read(filename::AbstractString, T::Type{Waveform})

    D = Dict{Int8, Int8}()
    for line ∈ readlines(filename)
        if startswith(line, "#")
            continue
        end

        key, value = split(line)
        key, value = parse.(Int8, [key, value])

        D[key] = value
    end

    T(D)
end
"""
Certain parameters which define an acoustic event.
"""
struct AcousticsTriggerParameter
    q::Float64
    tmax::Float64
    nmin::Int32
end
"""
    function read(filename::AbstractString, T::Type{AcousticsTriggerParameter})

Reads the 'acoustics_trigger_parameters.txt' file.
"""
function read(filename::AbstractString, T::Type{AcousticsTriggerParameter})
    lines = readlines(filename)
    q = split(split(lines[1])[end], ";")[1]
    tmax = split(split(lines[2])[end], ";")[1]
    nmin = split(split(lines[3])[end], ";")[1]

    q = parse(Float64, q)
    tmax = parse(Float64, tmax)
    nmin = parse(Int32, nmin)

    T(q, tmax, nmin)
end

const DETECTOR_COMMENT_PREFIX = "#"

"""
A KM3NeT detector.

"""
struct Detector
    version::Int8
    id::Int32
    validity::Union{DateRange, Missing}
    pos::Union{UTMPosition{Float64}, Missing}
    utm_ref_grid::Union{String, Missing}
    n_modules::Int32
    modules::Dict{Int32, DetectorModule}
    locations::Dict{Tuple{Int, Int}, DetectorModule}
    strings::Vector{Int}
    comments::Vector{String}
end
Base.show(io::IO, d::Detector) = print(io, "Detector $(d.id) (v$(d.version)) with $(length(d.strings)) strings and $(d.n_modules) modules.")
Base.length(d::Detector) = d.n_modules
Base.eltype(::Type{Detector}) = DetectorModule
function Base.iterate(d::Detector, state=(Int[], 1))
    module_ids, count = state
    count > d.n_modules && return nothing
    if count == 1
        module_ids = collect(keys(d.modules))
    end
    (d.modules[module_ids[count]], (module_ids, count + 1))
end
Base.getindex(d::Detector, module_id) = d.modules[module_id]


"""

Calculate the center of the detector based on the location of the optical modules.

"""
function center(d::Detector)
    opticalmodules = [m for m ∈ d if !isbasemodule(m)]
    sum(m.pos for m ∈ opticalmodules) / length(opticalmodules)
end


"""
    function Detector(filename::AbstractString)

Create a `Detector` instance from a DETX file.
"""
function Detector(filename::AbstractString)
    open(filename, "r") do fobj
        Detector(fobj)
    end
end


"""
    function Detector(io::IO)

Create a `Detector` instance from an IO stream.
"""
function Detector(io::IO)
    lines = readlines(io)

    comments = _extract_comments(lines, DETECTOR_COMMENT_PREFIX)

    filter!(e->!startswith(e, DETECTOR_COMMENT_PREFIX) && !isempty(strip(e)), lines)

    first_line = lowercase(first(lines))  # version can be v or V, halleluja

    if occursin("v", first_line)
        det_id, version = map(x->parse(Int,x), split(first_line, 'v'))
        validity = DateRange(map(unix2datetime, map(x->parse(Float64, x), split(lines[2])))...)
        utm_position = UTMPosition(map(x->parse(Float64, x), split(lines[3])[4:6])...)
        utm_ref_grid = join(split(lines[3])[2:3], " ")
        n_modules = parse(Int, lines[4])
        idx = 5
    else
        det_id, n_modules = map(x->parse(Int,x), split(first_line))
        version = 1
        utm_position = missing
        utm_ref_grid = missing
        validity = missing
        idx = 2
    end

    modules = Dict{Int32, DetectorModule}()
    locations = Dict{Tuple{Int, Int}, DetectorModule}()
    strings = Int8[]

    for mod ∈ 1:n_modules
        elements = split(lines[idx])
        module_id, string, floor = map(x->parse(Int, x), elements[1:3])
        if !(string in strings)
            push!(strings, string)
        end

        if version >= 4
            x, y, z, q0, qx, qy, qz, t₀ = map(x->parse(Float64, x), elements[4:12])
            pos = Position(x, y, z)
            q = Quaternion(q0, qx, qy, qz)
        else
            pos = missing
            q = missing
            t₀ = missing
        end
        if version >= 5
            status = parse(Float64, elements[12])
        else
            status = 0  # default value is 0: module OK
        end
        n_pmts = parse(Int, elements[end])

        pmts = PMT[]
        for pmt in 1:n_pmts
            l = split(lines[idx+pmt])
            pmt_id = parse(Int,first(l))
            x, y, z, dx, dy, dz = map(x->parse(Float64, x), l[2:7])
            t0 = parse(Float64,l[8])
            if version >= 3
                pmt_status = parse(Int, l[9])
            else
                pmt_status = 0  # default value is 0: PMT OK
            end
            push!(pmts, PMT(pmt_id, Position(x, y, z), Direction(dx, dy, dz), t0, pmt_status))
        end

        if (ismissing(t₀) || t₀ == 0.0) && floor > 0
            # t₀ is only available in DETX v4+ and even with supported versions, the value is
            # sometimes 0 when e.g. the DETX was converted with Jpp from a version which did
            # not include that informatino (v3 and below). Here, we are using the averaged
            # PMT t₀s for the module t₀, just like Jpp does nowadays.
            t₀ = mean([pmt.t₀ for pmt in pmts])
        end

        if ismissing(t₀) && floor == 0
            t₀ = 0.0
        end

        if ismissing(pos)
            # Similar to the module t₀, the module position was introduced in DETX v4.
            # If this is missing, it will be set to the crossing point of the PMT axes.
            # If it's a base module, the position is set to (0, 0, 0).
            if length(pmts) > 0
                pos = center(pmts)
            else
                pos = Position(0, 0, 0)
            end
        end

        m = DetectorModule(module_id, pos, Location(string, floor), n_pmts, pmts, q, status, t₀)
        modules[module_id] = m
        locations[(string, floor)] = m
        idx += n_pmts + 1
    end

    Detector(version, det_id, validity, utm_position, utm_ref_grid, n_modules, modules, locations, strings, comments)
end



"""
    function _extract_comments(lines<:Vector{AbstractString}, prefix<:AbstractString)

Returns only the lines which are comments, identified by the `prefix`. The prefix is
omitted.

"""
function _extract_comments(lines::Vector{T}, prefix::T) where {T<:AbstractString}
    comments = String[]
    prefix_length = length(prefix)
    for line ∈ lines
        if startswith(line, prefix)
            comment = strip(line[prefix_length+1:end])
            push!(comments, comment)
        end
    end
    comments
end


"""
Writes the detector definition to a file, according to the DETX format specification.
The `version` parameter can be a version number or `:same`, which is the default value
and writes the same version as the provided detector has.
"""
function write(filename::AbstractString, d::Detector; version=:same)
    isfile(filename) && @warn "File '$(filename)' already exists, overwriting."
    open(filename, "w") do fobj
        write(fobj, d; version=version)
    end
end


# Helper function to write a line with a new line at the end
writeln(io::IO, line) = write(io, line * "\n")

"""
    function write(io::IO, d::Detector; version=:same)

Writes the detector to a DETX formatted file. The target version can be specified
via the `version` keyword. Note that if converting to higher versions, missing
parameters will be filled with reasonable default values. In case of downgrading,
information will be lost.
"""
function write(io::IO, d::Detector; version=:same)
    if version == :same
        version = d.version
    else
        version != d.version && println("Converting detector from format version $(d.version) to $(version).")
    end
    version > d.version && @warn "Target version is higher, missing parameters will be filled with reasonable default values."

    if version >= 3
        for comment in d.comments
            writeln(io, "$(DETECTOR_COMMENT_PREFIX) $(comment)")
        end
    end
    if version == 1
        writeln(io, "$(d.id) $(d.n_modules)")
    elseif version > 1
        writeln(io, "$(d.id) v$(version)")
    end

    if version > 1
        if ismissing(d.validity)
            valid_from = 0.0
            valid_to = 9999999999.0
        else
            valid_from = datetime2unix(d.validity.from)
            valid_to = datetime2unix(d.validity.to)
        end
        @printf(io, "%.1f %.1f\n", valid_from, valid_to)
        if ismissing(d.pos)
            utm_ref_grid = "WGS84 32N"  # grid of ORCA and ARCA
            east = 0
            north = 0
            z = 0
        else
            utm_ref_grid = d.utm_ref_grid
            east = d.pos.east
            north = d.pos.north
            z = d.pos.z
        end
        @printf(io, "UTM %s %.3f %.3f %.3f\n", utm_ref_grid, east, north, z)
    end

    if version > 1
        writeln(io, "$(d.n_modules)")
    end

    # TODO: module sorting is not needed according to specs but Jpp has problems with it
    for mod in sort(collect(values(d.modules)); by=m->(m.location.string, m.location.floor))
        if version < 4
            writeln(io, "$(mod.id) $(mod.location.string) $(mod.location.floor) $(mod.n_pmts)")
        else
            if ismissing(mod.q)
                q0, qx, qy, qz = (0, 0, 0, 0)
            else
                q0, qx, qy, qz = mod.q
            end
            if version == 4
                @printf(io, "%d %d %d %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %d\n", mod.id, mod.location.string, mod.location.floor, mod.pos.x, mod.pos.y, mod.pos.z, q0, qx, qy, qz, mod.t₀, mod.n_pmts)
            end
            if version > 4
                @printf(io, "%d %d %d %.8f %.8f %.8f %.8f %.8f %.8f %.8f %.8f %d %d\n", mod.id, mod.location.string, mod.location.floor, mod.pos.x, mod.pos.y, mod.pos.z, q0, qx, qy, qz, mod.t₀, mod.status, mod.n_pmts)
            end
        end
        for pmt in mod
            @printf(io, " %d %.8f %.8f %.8f %.8f %.8f %.8f %.8f",  pmt.id, pmt.pos.x, pmt.pos.y, pmt.pos.z, pmt.dir.x, pmt.dir.y, pmt.dir.z, pmt.t₀)
            if version >= 3
                @printf(io, " %d", pmt.status)
            end
            write(io, "\n")
        end
    end
end
