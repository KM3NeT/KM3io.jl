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
    status::Int32
end
function Base.isapprox(lhs::PMT, rhs::PMT; kwargs...)
    for field in [:id, :status]
        getfield(lhs, field) == getfield(rhs, field) || return false
    end
    for field in [:pos, :dir, :t₀]
        isapprox(getfield(lhs, field), getfield(rhs, field); kwargs...) || return false
    end
end

"""
The physical address of a PMT consisting of the ring (A-F) and the position (1-6).
"""
struct PMTPhysicalAddress
    ring::Char
    position::Int
end


const _PMTAddressMap = SVector(
    PMTPhysicalAddress('F', 4),
    PMTPhysicalAddress('E', 5),
    PMTPhysicalAddress('E', 4),
    PMTPhysicalAddress('E', 3),
    PMTPhysicalAddress('F', 3),
    PMTPhysicalAddress('F', 5),
    PMTPhysicalAddress('E', 2),
    PMTPhysicalAddress('F', 6),
    PMTPhysicalAddress('F', 2),
    PMTPhysicalAddress('F', 1),
    PMTPhysicalAddress('E', 1),
    PMTPhysicalAddress('E', 6),
    PMTPhysicalAddress('D', 1),
    PMTPhysicalAddress('C', 1),
    PMTPhysicalAddress('B', 1),
    PMTPhysicalAddress('D', 2),
    PMTPhysicalAddress('D', 6),
    PMTPhysicalAddress('C', 6),
    PMTPhysicalAddress('B', 6),
    PMTPhysicalAddress('B', 2),
    PMTPhysicalAddress('C', 5),
    PMTPhysicalAddress('C', 2),
    PMTPhysicalAddress('A', 1),
    PMTPhysicalAddress('D', 3),
    PMTPhysicalAddress('B', 4),
    PMTPhysicalAddress('B', 3),
    PMTPhysicalAddress('B', 5),
    PMTPhysicalAddress('D', 5),
    PMTPhysicalAddress('C', 4),
    PMTPhysicalAddress('C', 3),
    PMTPhysicalAddress('D', 4)
)
"""
Get the physical address of a PMT.
"""
getaddress(channel_id::Integer) = _PMTAddressMap[channel_id + 1]


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
Base.isless(lhs::Location, rhs::Location) = lhs.string == rhs.string ? lhs.floor < rhs.floor : lhs.string < rhs.string


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
    q::Quaternion{Float64}
    status::Int32
    t₀::Float64
end
Base.length(d::DetectorModule) = d.n_pmts
Base.eltype(::Type{DetectorModule}) = PMT
Base.iterate(d::DetectorModule, state=1) = state > d.n_pmts ? nothing : (d.pmts[state], state+1)
Base.isless(lhs::DetectorModule, rhs::DetectorModule) = lhs.location < rhs.location
function Base.isapprox(lhs::DetectorModule, rhs::DetectorModule; kwargs...)
    for field in [:id, :location, :n_pmts, :status]
        getfield(lhs, field) == getfield(rhs, field) || return false
    end
    for field in [:pos, :q, :t₀]
        isapprox(getfield(lhs, field), getfield(rhs, field); kwargs...) || return false
    end
    for (lhs_pmt, rhs_pmt) in zip(lhs.pmts, rhs.pmts)
        isapprox(lhs_pmt, rhs_pmt; kwargs...)
    end
    true
end
"""
    Base.getindex(d::DetectorModule, i) = d.pmts[i+1]

The index in this context is the DAQ channel ID of the PMT, which is counting from 0.
"""
Base.getindex(d::DetectorModule, i) = d.pmts[i+1]
"""
Returns true if the module is a basemodule.
"""
isbasemodule(d::DetectorModule) = d.location.floor == 0
"""
Returns true if the module is an optical module.
"""
isopticalmodule(d::DetectorModule) = d.n_pmts > 0
getpmts(d::DetectorModule) = d.pmts
"""
Get the PMT for a given DAQ channel ID (TDC)
"""
getpmt(d::DetectorModule, channel_id::Integer) = d[channel_id]

Base.filter(f::Function, d::DetectorModule) = filter(f, getpmts(d))

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
    validity::DateRange
    pos::UTMPosition
    lonlat::LonLatExtended
    utm_ref_grid::String
    n_modules::Int32
    modules::Dict{Int32, DetectorModule}
    locations::Dict{Tuple{Int, Int}, DetectorModule}
    strings::Vector{Int}
    comments::Vector{String}
    _pmt_id_module_map::Dict{Int, DetectorModule}
end

"""
Return a vector of all modules of a given detector.
"""
modules(d::Detector) = collect(values(d.modules))
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
function Base.getindex(d::Detector, module_id::Integer)
    haskey(d.modules, module_id) && return d.modules[module_id]
    error("Module with ID $(module_id) not found.")
end
function Base.getindex(d::Detector, string::Integer, floor::Integer)
    haskey(d.locations, (string, floor)) && return d.locations[string, floor]
    available_strings = join(d.strings, ", ", " and ")
    !(hasstring(d, string)) && error("String $(string) not found. Available strings: $(available_strings).")
    error("String $(string) has no module at floor $(floor).")
end
"""
    lonlat(detector::Detector) -> LonLatExtended
"""
@inline KM3Base.lonlat(detector::Detector) = detector.lonlat
"""
Return the detector module for a given module ID.
"""
@inline getmodule(d::Detector, module_id::Integer) = d[module_id]
"""
Return the detector module for a given string and floor.
"""
@inline getmodule(d::Detector, string::Integer, floor::Integer) = d[string, floor]
"""
Return the detector module for a given string and floor (as `Tuple`).
"""
@inline getmodule(d::Detector, loc::Tuple{T, T}) where T<:Integer = d[loc...]
"""
Return the detector module for a given location.
"""
@inline getmodule(d::Detector, loc::Location) = d[loc.string, loc.floor]
"""
Return the `PMT` for a given hit.
"""
@inline getpmt(d::Detector, hit::AbstractDAQHit) = getpmt(getmodule(d, hit.dom_id), hit.channel_id)
"""
Return the detector module for a given DAQ hit.
"""
@inline getmodule(d::Detector, hit::AbstractDAQHit) = getmodule(d, hit.dom_id)
"""
Return the detector module for a given MC hit.
"""
@inline getmodule(d::Detector, hit::AbstractMCHit) = d._pmt_id_module_map[hit.pmt_id]
Base.getindex(d::Detector, string::Int, ::Colon) = sort!(filter(m->m.location.string == string, modules(d)))
Base.getindex(d::Detector, string::Int, floors::T) where T<:Union{AbstractArray, UnitRange} = [d[string, floor] for floor in sort(floors)]
Base.getindex(d::Detector, ::Colon, floor::Int) = sort!(filter(m->m.location.floor == floor, modules(d)))
"""
Return a vector of detector modules for a given range of floors on all strings.

This can be useful if specific detector module layers of the detector are needed, e.g.
the base modules (e.g. `detector[:, 0]`) or the top layer (e.g. `detector[:, 18]`).
"""
function Base.getindex(d::Detector, ::Colon, floors::UnitRange{T}) where T<:Integer
    modules = DetectorModule[]
    for string in d.strings
        for floor in floors
            push!(modules, d[string, floor])
        end
    end
    sort!(modules)
end

Base.filter(f::Function, d::Detector) = filter(f, modules(d))

"""

Returns true if there is a module at the given location.

"""
haslocation(d::Detector, loc::Location) = haskey(d.locations, (loc.string, loc.floor))

"""

Returns true if there is a string with a given number.

"""
hasstring(d::Detector, s::Integer) = s in d.strings


"""

Calculate the center of the detector based on the location of the optical modules.

"""
function center(d::Detector)
    opticalmodules = [m for m ∈ d if !isbasemodule(m)]
    sum(m.pos for m ∈ opticalmodules) / length(opticalmodules)
end


"""
    function Detector(filename::AbstractString)

Create a `Detector` instance from a DETX/DATX file.
"""
function Detector(filename::AbstractString)::Detector
    _, ext = splitext(filename)
    if ext == ".detx"
        return open(filename, "r") do fobj
            read_detx(fobj)
        end
    elseif ext == ".datx"
        return open(filename, "r") do fobj
            read_datx(fobj)
        end
    end
    error("Unsupported detector file format '$(filename)'")
end


"""
    function read_detx(io::IO)

Create a `Detector` instance from an ASCII IO stream using the DATX specification.
"""
function read_datx(io::IO)
    comment_marker = [0x23, 0x23, 0x23, 0x23]
    supported_versions = Set(5)

    comments = String[]
    while read(io, 4) == comment_marker
        push!(comments, _readstring(io))
    end
    seek(io, max(0, position(io) - length(comment_marker)))
    det_id = read(io, Int32)
    version = parse(Int, _readstring(io)[2:end])
    if !(version ∈ supported_versions)
        error("DATX version $version is not supported yet. Supported versions are: $(join(supported_versions, ' '))")
    end
    validity = DateRange(unix2datetime(read(io, Float64)), unix2datetime(read(io, Float64)))
    _readstring(io)  # says "UTM", ignoring
    wgs = _readstring(io)
    zone = _readstring(io)
    zone_number = parse(Int, match(r"^\d+", zone).match)
    utm_ref_grid = "$wgs $zone"
    zone_letter = utm_ref_grid[end]
    utm_position = UTMPosition(read(io, Float64), read(io, Float64), zone_number, zone_letter, read(io, Float64))
    n_modules = read(io, Int32)

    modules = Dict{Int32, DetectorModule}()
    locations = Dict{Tuple{Int, Int}, DetectorModule}()
    strings = Int[]
    _pmt_id_module_map = Dict{Int, DetectorModule}()
    for _ in 1:n_modules
        module_id = read(io, Int32)
        location = Location(read(io, Int32), read(io, Int32))
        if !(location.string in strings)
            push!(strings, location.string)
        end
        module_pos = Position{Float64}(read(io, Float64), read(io, Float64), read(io, Float64))
        q = Quaternion{Float64}(read(io, Float64), read(io, Float64), read(io, Float64), read(io, Float64))
        module_t₀ = read(io, Float64)
        module_status = read(io, Int32)
        n_pmts = read(io, Int32)
        pmts = PMT[]
        for _ in 1:n_pmts
            pmt_id = read(io, Int32)
            pmt_pos = Position{Float64}(read(io, Float64), read(io, Float64), read(io, Float64))
            pmt_dir = Direction{Float64}(read(io, Float64), read(io, Float64), read(io, Float64))
            pmt_t₀ = read(io, Float64)
            pmt_status = read(io, Int32)
            push!(pmts, PMT(pmt_id, pmt_pos, pmt_dir, pmt_t₀, pmt_status))
        end
        m = DetectorModule(module_id, module_pos, location, n_pmts, pmts, q, module_status, module_t₀)
        for pmt in pmts
            _pmt_id_module_map[pmt.id] = m
        end
        modules[module_id] = m
        locations[(location.string, location.floor)] = m
    end
    Detector(version, det_id, validity, utm_position, lonlat(utm_position), utm_ref_grid, n_modules, modules, locations, strings, comments, _pmt_id_module_map)
end
@inline _readstring(io) = String(read(io, read(io, Int32)))

"""
    function read_detx(io::IO)

Create a `Detector` instance from an ASCII IO stream using the DETX specification.
"""
function read_detx(io::IO)
    comments, lines = _split_comments(readlines(io), DETECTOR_COMMENT_PREFIX)

    filter!(e->!startswith(e, DETECTOR_COMMENT_PREFIX) && !isempty(strip(e)), lines)

    first_line = lowercase(first(lines))  # version can be v or V, halleluja

    if occursin("v", first_line)
        det_id, version = map(x->parse(Int,x), split(first_line, 'v'))
        validity = DateRange(map(unix2datetime, map(x->parse(Float64, x), split(lines[2])))...)
        utm_ref_grid = join(split(lines[3])[2:3], " ")
        zone_number = parse(Int, match(r"^\d+", split(utm_ref_grid)[2]).match)
        zone_letter = utm_ref_grid[end]
        easting, northing, z = map(x->parse(Float64, x), split(lines[3])[4:6])
        n_modules = parse(Int, lines[4])
        idx = 5
    else  # this is v1
        det_id, n_modules = map(x->parse(Int,x), split(first_line))
        version = 1
        utm_position = UTMPosition(0, 0, 0, 0, 0)
        utm_ref_grid = "WGS84 0X"  # an invalid zone
        zone_number = 0
        zone_letter = 'X'
        easting = northing = z = 0.0
        validity = DateRange(unix2datetime(0.), unix2datetime(999999999999.9))  # fallback
        idx = 2
    end

    utm_position = UTMPosition(easting, northing, zone_number, zone_letter, z)

    modules = Dict{Int32, DetectorModule}()
    locations = Dict{Tuple{Int, Int}, DetectorModule}()
    strings = Int32[]
    _pmt_id_module_map = Dict{Int, DetectorModule}()

    # a counter to work around the floor == -1 bug in some older DETX files
    floor_counter = 1
    last_string = -1
  
    for mod ∈ 1:n_modules
        elements = split(lines[idx])
        module_id, string, floor = map(x->parse(Int, x), elements[1:3])

        # floor == -1 bug. We determine the floor position by assuming an ascending order
        # of modules in the DETX file
        if floor == -1
            if last_string == -1
                last_string = string
            elseif last_string != string
                floor_counter = 1
                last_string = string
            end
            floor = floor_counter
            floor_counter += 1
        end

        if !(string in strings)
            push!(strings, string)
        end

        if version >= 4
            x, y, z, q0, qx, qy, qz, t₀ = map(x->parse(Float64, x), elements[4:12])
            pos = Position(x, y, z)
            q = Quaternion(q0, qx, qy, qz)
        else
            pos = missing  # dealing with it later
            q = Quaternion(0.0, 0.0, 0.0, 0.0)
            t₀ = missing  # dealing with it later
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

        # If t₀ is missing, we default to 0.0
        if ismissing(t₀)
            t₀ = 0.0
        end

        if ismissing(pos)
            # Similar to the module t₀, the module position was introduced in DETX v4.
            # If this is missing, it will be set to the crossing point of the PMT axes.
            # If it's a base module, the position is set to (0, 0, 0).
            if length(pmts) > 0
                pos = center(pmts)
            else
                pos = Position(0.0, 0.0, 0.0)
            end
        end

        m = DetectorModule(module_id, pos, Location(string, floor), n_pmts, pmts, q, status, t₀)
        modules[module_id] = m
        locations[(string, floor)] = m
        for pmt in pmts
            _pmt_id_module_map[pmt.id] = m
        end

        idx += n_pmts + 1
    end

    Detector(version, det_id, validity, utm_position, lonlat(utm_position), utm_ref_grid, n_modules, modules, locations, strings, comments, _pmt_id_module_map)
end



"""
    function _split_comments(lines<:Vector{AbstractString}, prefix<:AbstractString)

Returns a tuple of comments and content. Comment lines are identified by the `prefix`.
The prefix is omitted.

"""
function _split_comments(lines::Vector{T}, prefix::T) where {T<:AbstractString}
    comments = String[]
    content = String[]
    prefix_length = length(prefix)
    # Multiline comments are not part of the specification but
    # there are DETX containing such (introduced by Jpp).
    # This feature is just a workaround until we define proper
    # multiline comments for DETX/DATX v6+
    multilinemode = false
    for line ∈ lines
        if multilinemode
            if length(findall(raw"\"", line)) == 1
                multilinemode = false
            end
            push!(comments, line)
            continue
        end
        if startswith(line, prefix)
            comment = strip(line[prefix_length+1:end])
            if length(findall(raw"\"", comment)) == 1
                multilinemode = true
            end
            push!(comments, comment)
        end
        push!(content, line)
    end
    comments, content
end


"""
Writes the detector definition to a file, according to the DETX format specification.
The `version` parameter can be a version number or `:same`, which is the default value
and writes the same version as the provided detector has.
"""
function write(filename::AbstractString, d::Detector; version=:same)
    !endswith(filename, ".detx") && error("Only DETX is supported for detector writing.")
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
    end

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
        valid_from = datetime2unix(d.validity.from)
        valid_to = datetime2unix(d.validity.to)
        @printf(io, "%.1f %.1f\n", valid_from, valid_to)
        utm_ref_grid = d.utm_ref_grid
        east = d.pos.easting
        north = d.pos.northing
        z = d.pos.z
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
            q0, qx, qy, qz = mod.q
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


"""

Data structure for parameters of the mechanical model of strings. This data
structure is used to calculate the effective height conform to the mechanical
model of the string.

"""
struct StringMechanicsParameters
    a::Float64  # logarithmic term
    b::Float64  # linear term
end

"""

A container structure which holds the mechanical model parameters for multiple
strings, including a default value for strings which have specific parameters.

"""
struct StringMechanics
    default::StringMechanicsParameters
    stringparams::Dict{Int, StringMechanicsParameters}
end
Base.getindex(s::StringMechanics, idx::Integer) = get(s.stringparams, idx, s.default)


"""

Reads the mechanical models from a text file.

"""
function read(filename::AbstractString, T::Type{StringMechanics})
    stringparams = Dict{Int, StringMechanicsParameters}()
    default_a = 0.0
    default_b = 0.0
    for line ∈ readlines(filename)
        if startswith(line, "#")
            continue
        end
        string, a, b = split(line)
        s = parse(Int, string)
        a = parse(Float64, a)
        b = parse(Float64, b)
        if s == -1  # wildcard for any string
            default_a = a
            default_b = b
        else
            stringparams[s] = StringMechanicsParameters(a, b)
        end
    end
    T(StringMechanicsParameters(default_a, default_b), stringparams)
end

"""
Canonical (factory reference) PMT directions for a KM3NeT optical module,
ordered by DAQ channel (TDC) index 0–30. From `JDetectorSupportkit.hh` and
the `JKM3NeT_t` address map in Jpp.

The ordering follows the KM3NeT standard address map (`JDetectorBuilder_t<JKM3NeT_t>`)
which maps PMT numbers 1–31 to TDC channels 0–30.  This is the order in which
PMTs appear in DETX/DATX files produced by Jpp, and the order used by
`reference_rotation` when computing the rotation from the canonical frame to
the static detector geometry.
"""
const CANONICAL_PMT_DIRECTIONS = Direction{Float64}[
    Direction(+0.000, -0.832, +0.555),  # ch  0  (PMT 29)
    Direction(-0.955, +0.000, +0.295),  # ch  1  (PMT 24)
    Direction(-0.478, -0.827, +0.295),  # ch  2  (PMT 23)
    Direction(+0.478, -0.827, +0.295),  # ch  3  (PMT 22)
    Direction(+0.720, -0.416, +0.555),  # ch  4  (PMT 28)
    Direction(-0.720, -0.416, +0.555),  # ch  5  (PMT 30)
    Direction(+0.955, +0.000, +0.295),  # ch  6  (PMT 21)
    Direction(-0.720, +0.416, +0.555),  # ch  7  (PMT 31)
    Direction(+0.720, +0.416, +0.555),  # ch  8  (PMT 27)
    Direction(+0.000, +0.832, +0.555),  # ch  9  (PMT 26)
    Direction(+0.478, +0.827, +0.295),  # ch 10  (PMT 20)
    Direction(-0.478, +0.827, +0.295),  # ch 11  (PMT 25)
    Direction(+0.000, +0.955, -0.295),  # ch 12  (PMT 14)
    Direction(+0.416, +0.720, -0.555),  # ch 13  (PMT  8)
    Direction(+0.000, +0.527, -0.850),  # ch 14  (PMT  2)
    Direction(+0.827, +0.478, -0.295),  # ch 15  (PMT 15)
    Direction(-0.827, +0.478, -0.295),  # ch 16  (PMT 19)
    Direction(-0.416, +0.720, -0.555),  # ch 17  (PMT 13)
    Direction(-0.456, +0.263, -0.850),  # ch 18  (PMT  7)
    Direction(+0.456, +0.263, -0.850),  # ch 19  (PMT  3)
    Direction(-0.832, +0.000, -0.555),  # ch 20  (PMT 12)
    Direction(+0.832, +0.000, -0.555),  # ch 21  (PMT  9)
    Direction(+0.000, +0.000, -1.000),  # ch 22  (PMT  1, bottom)
    Direction(+0.827, -0.478, -0.295),  # ch 23  (PMT 16)
    Direction(+0.000, -0.527, -0.850),  # ch 24  (PMT  5)
    Direction(+0.456, -0.263, -0.850),  # ch 25  (PMT  4)
    Direction(-0.456, -0.263, -0.850),  # ch 26  (PMT  6)
    Direction(-0.827, -0.478, -0.295),  # ch 27  (PMT 18)
    Direction(-0.416, -0.720, -0.555),  # ch 28  (PMT 11)
    Direction(+0.416, -0.720, -0.555),  # ch 29  (PMT 10)
    Direction(+0.000, -0.955, -0.295),  # ch 30  (PMT 17)
]

struct PMTParameters
    QE::Float64  # probability of underamplified hit
    PunderAmplified::Float64  # probability of underamplified hit
    TTS_ns::Float64  # transition time spread [ns]
    gain::Float64  # [unit]
    gainSpread::Float64  # [unit]
    mean_ns::Float64  # mean time-over-threshold of threshold-band hits [ns]
    riseTime_ns::Float64  # rise time of analogue pulse [ns]
    saturation::Float64  # [ns]
    sigma_ns::Float64 # time-over-threshold standard deviation of threshold-band hits [ns]
    slewing::Bool # time slewing of analogue signal
    slope::Float64  # [ns/npe]
    threshold::Float64  # [npe]
    thresholdBand::Float64  # [npe]
end
Base.isvalid(p::PMTParameters) = !(p.QE < 0 || p.gain < 0 || p.gainSpread < 0 || p.threshold < 0 || p.thresholdBand < 0)

"""

PMT parameters as stored in [`PMTFile`](@ref)s.

"""
struct PMTData
    QE::Float64
    gain::Float64
    gainSpread::Float64
    riseTime_ns::Float64
    TTS_ns::Float64
    threshold::Float64
end

"""

A container type to hold PMT data which are stored in "PMT files", created by
K40 calibrations. This type can be passe to `Base.read` to load the contents
of such a file.

# Example

```
julia> f = read("path/to/pmt.txt", PMTFile)
PMTFile containing parameters of 7254 PMTs
```

"""
struct PMTFile
    QE::Float64  # relative quantum efficiency
    mu::Float64
    comments::Vector{String}
    parameters::PMTParameters
    pmt_data::Dict{Tuple{Int, Int}, PMTData}
end
function Base.show(io::IO, p::PMTFile)
    print(io, "PMTFile containing parameters of $(length(p.pmt_data)) PMTs")
end
Base.getindex(p::PMTFile, dom_id::Integer, channel_id::Integer) = p.pmt_data[dom_id, channel_id]

"""

Read PMT parameters from a K40 calibration output file.

"""
function read(filename::AbstractString, ::Type{PMTFile})
    pmt_data = Dict{Tuple{Int, Int}, PMTData}()
    fobj = open(filename, "r")
    comments, content = _split_comments(readlines(fobj), "#")
    close(fobj)

    QE=0
    mu=0
    raw_pmt_parameters = Dict{Symbol, Float64}()
    pmt_data = Dict{Tuple{Int, Int}, PMTData}()
    for line in content
        startswith(line, "#") && continue
        if startswith(line, "QE=")
            QE = parse(Float64, split(line, "=")[2])
            continue
        end
        if startswith(line, "mu")
            mu = parse(Float64, split(line, "=")[2])
            continue
        end
        m = match(r"%\.(.+)=(.+)", line)
        if !isnothing(m)
            raw_pmt_parameters[Symbol(m[1])] = parse(Float64, m[2])
            continue
        end
        if startswith(line, "PMT=")
            sline = split(line)
            dom_id = parse(Int, sline[2])
            channel_id = parse(Int, sline[3])
            pmt_data[(dom_id, channel_id)] = PMTData([parse(t, v) for (t, v) in zip(fieldtypes(PMTData), sline[4:9])]...)
            continue
        end
    end

    pmt_parameters = PMTParameters([raw_pmt_parameters[f] for f in fieldnames(PMTParameters)]...)
    PMTFile(QE, mu, comments, pmt_parameters, pmt_data)
end

const _detoid_detid_map = Dict(
    "D_DU1CPPM" => 2,
    "A00350276" => 3,
    "D_DU2NAPO" => 5,
    "D_TESTDET" => 6,
    "D_ARCA001" => 7,
    "D_DU003NA" => 9,
    "D_DU004NA" => 12,
    "D_DU001MA" => 13,
    "D_ARCA003" => 14,
    "A01495728" => 21,
    "A01495762" => 22,
    "D_BCI0001" => 23,
    "D_NAP0001" => 24,
    "D0DU001MA" => 26,
    "D0DU002MA" => 28,
    "D_ORCA002" => 29,
    "INTTEST01" => 32,
    "D_BCI0003" => 35,
    "DOLDDU1MA" => 36,
    "D1DU002MA" => 37,
    "D0DU003MA" => 38,
    "D0DU004MA" => 39,
    "D_ORCA003" => 40,
    "D0DU005MA" => 41,
    "D0ARCA001" => 42,
    "D_ORCA004" => 43,
    "D_ORCA005" => 44,
    "D0DU006MA" => 46,
    "D0DU007MA" => 47,
    "D_BCI0004" => 48,
    "D_ORCA006" => 49,
    "D0DU038CT" => 52,
    "D0BCIW001" => 56,
    "D0DU039CT" => 57,
    "D1DU039CT" => 59,
    "D0DU040CE" => 60,
    "D0DU041CT" => 61,
    "D1DU040CE" => 62,
    "D0DU069MA" => 63,
    "D0DU044CT" => 64,
    "D0DU049CE" => 65,
    "D0BCIW002" => 66,
    "D0DU067MA" => 67,
    "D0ARCA006" => 75,
    "D0DU047CT" => 76,
    "D0DU068MA" => 77,
    "D0DU045CE" => 78,
    "D0DU070MA" => 79,
    "D0DU051CT" => 80,
    "D0DU043CE" => 81,
    "D0DU042CT" => 82,
    "D0DU046CE" => 83,
    "D0DU071MA" => 84,
    "D1DU042CT" => 85,
    "D0DU072MA" => 86,
    "D0DU054CE" => 87,
    "D1DU068MA" => 88,
    "D0DU056CT" => 89,
    "D0DU052CE" => 90,
    "D0BCIW003" => 91,
    "D0DU073MA" => 93,
    "D0ARCA009" => 94,
    "D0DU048CE" => 95,
    "D0DU074MA" => 96,
    "D0DU053CT" => 97,
    "D0ORCA013" => 98,
    "D0DU055CE" => 99,
    "D0ORCA010" => 100,
    "D0DU059CT" => 101,
    "D1DU054CE" => 102,
    "D1DU059CT" => 103,
    "D2DU059CT" => 104,
    "D0DU057CT" => 105,
    "D0DU079MA" => 106,
    "D0DU050CT" => 107,
    "D0DU058CE" => 108,
    "D0ORCA007" => 110,
    "D0DU063CE" => 111,
    "D1DU043CE" => 112,
    "D1DU067MA" => 113,
    "D0ARCA020" => 116,
    "D1ORCA013" => 117,
    "D0ORCA012" => 119,
    "D0DU080MA" => 120,
    "D0DU062CT" => 121,
    "D0DU064CT" => 122,
    "D0ORCA011" => 123,
    "D0DU075MA" => 124,
    "D0DU078MA" => 125,
    "D2ORCA013" => 127,
    "D1ORCA011" => 132,
    "D0ARCA021" => 133,
    "D0DU036MA" => 134,
    "D1DU071MA" => 135,
    "D0DU085MA" => 136,
    "D0ORCA016" => 137,
    "D0ORCA015" => 138,
    "D0DU061CE" => 139,
    "D0DU065CE" => 140,
    "D0DU077MA" => 141,
    "D1DU079MA" => 142,
    "D0DU097CE" => 143,
    "D2DU040CE" => 144,
    "D0DU087MA" => 145,
    "D1ORCA015" => 146,
    "D0DU089MA" => 147,
    "D0ORCA018" => 148,
    "D0DU095CT" => 149,
    "D0DU081MA" => 150,
    "D0DU060CE" => 151,
    "D0DU066CT" => 152,
    "D0DU091MA" => 153,
    "D0DU084MA" => 154,
    "D0DU082MA" => 155,
    "D1DU082MA" => 156,
    "D0DU101MA" => 157,
    "D1DU063CE" => 158,
    "D0ARCA031" => 159,
    "D0ARCA028" => 160,
    "D0DU093MA" => 161,
    "D0DU086MA" => 162,
    "D0DU083MA" => 163,
    "D0ORCA022" => 165,
    "D0DU100CE" => 166,
    "D1DU100CE" => 167,
    "D2DU100CE" => 168,
    "D0ORCA019" => 169,
    "D0DU129CT" => 170,
    "D1DU084MA" => 171,
    "D1ORCA019" => 172,
    "D0DU088MA" => 173,
    "D2DU042CT" => 174,
    "D1DU129CT" => 175,
    "D0DU096MA" => 176,
    "D0DU103CE" => 177,
    "D1DU103CE" => 178,
    "D2DU103CE" => 179,
    "D0DU105CE" => 180,
    "D0DU108CE" => 181,
    "D0DU090MA" => 182,
    "D0DU109CE" => 183,
    "D0DU102CT" => 184,
    "D0DU076MA" => 185,
    "D0BCIBW01" => 187,
    "D0DU104GE" => 188,
    "D0DU110CE" => 189,
    "D1DU110CE" => 190,
    "D0DU112CE" => 191,
    "D0DU107CT" => 192,
    "D0ORCA024" => 193,
    "D0DU115CE" => 194,
    "D0ORCA023" => 196,
    "D0BCIBW02" => 197,
    "D0DU106CE" => 198,
    "D0DU111CT" => 199,
    "D1DU111CT" => 200,
    "D0DU113CE" => 201,
    "D0DU114CT" => 202,
    "D1DU113CE" => 203,
    "D1ORCA023" => 204,
    "D0DU117CE" => 205,
    "D0DU116CT" => 206,
    "D00MDOMCE" => 208,
    "P0ARCA047" => 230,
    "D0ARCA030" => 232,
    "P0ARCW016" => 233,
    "D1ORCA024" => 234,
    "D1DU083MA" => 235,
    "D0ARCW003" => 236,
    "D0DU134MA" => 237,
    "D0DU118CT" => 238,
    "D0DU120GE" => 239,
    "D0DU119CE" => 240,
    "D0DU127CE" => 241,
    "D0DU092MA" => 242,
    "D0DU120CT" => 243,
    "D2ORCA024" => 244,
    "D0DU124GE" => 245,
    "D0DU125CT" => 246,
    "D0DU121CE" => 247,
    "D0DU126CT" => 248,
    "D0DU124CE" => 249,
    "P3ORCA030" => 252,
    "D0ORCA028" => 253,
    "D0DU122CE" => 254,
    "D0BCIBW03" => 257,
    "D0DU128GE" => 258,
    "P0ARCA053" => 260,
    "P0ARCW023" => 261,
    "P0ARCA054" => 262,
    "P0ARCW024" => 263,
    "D1ORCA028" => 264,
    "D0ARCA051" => 265,
    "D0ARCW021" => 266,
    "D1ARCA030" => 267,
    "D0DU133MA" => 268,
    "D0DU199MA" => 269,
    "D0DU152CT" => 270,
    "D0DU131MA" => 271,
    "D0DU123GE" => 272,
    "D0DU149CE" => 273,
    "D0ORCA033" => 274,
    "D0DU136MA" => 275,
    "D0DU150CE" => 276,
    "D1ARCA051" => 277,
    "D1DU133MA" => 278,
    "D0DU138MA" => 279,
    "D0DU135MA" => 280,
    "D0DU153GE" => 281,
)

"""
    detoid2detid(detoid::AbstractString) -> Int

Return the detector ID for a given detector OID string.

Throws a `KeyError` if the OID is not found.

# Example
```julia
julia> detoid2detid("D_ARCA001")
7
```
"""
function detoid2detid(detoid::AbstractString)
    return _detoid_detid_map[detoid]
end

const _detid_detoid_map = Dict(v => k for (k, v) in _detoid_detid_map)

"""
    detid2detoid(detid::Integer) -> String

Return the detector OID string for a given detector ID.

Throws a `KeyError` if the ID is not found.

# Example
```julia
julia> detid2detoid(7)
"D_ARCA001"
```
"""
function detid2detoid(detid::Integer)
    return _detid_detoid_map[detid]
end
