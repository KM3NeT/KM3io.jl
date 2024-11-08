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
function Base.isapprox(lhs::PMT, rhs::PMT; kwargs...)
    for field in [:id, :status]
        getfield(lhs, field) == getfield(rhs, field) || return false
    end
    for field in [:pos, :dir, :t₀]
        isapprox(getfield(lhs, field), getfield(rhs, field); kwargs...) || return false
    end
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
"""
Return a vector of all modules of a given detector.
"""
modules(d::Detector) = collect(values(d.modules))
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
Base.getindex(d::Detector, module_id::Integer) = d.modules[module_id]
Base.getindex(d::Detector, string::Integer, floor::Integer) = d.locations[string, floor]
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
@inline getpmt(d::Detector, hit) = getpmt(getmodule(d, hit.dom_id), hit.channel_id)
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

"""

Returns true if there is a module at the given location.

"""
haslocation(d::Detector, loc::Location) = haskey(d.locations, (loc.string, loc.floor))

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
    utm_ref_grid = "$wgs $zone"
    utm_position = UTMPosition(read(io, Float64), read(io, Float64), read(io, Float64))
    n_modules = read(io, Int32)

    modules = Dict{Int32, DetectorModule}()
    locations = Dict{Tuple{Int, Int}, DetectorModule}()
    strings = Int[]
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
        modules[module_id] = m
        locations[(location.string, location.floor)] = m
    end
    Detector(version, det_id, validity, utm_position, utm_ref_grid, n_modules, modules, locations, strings, comments)
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

    # a counter to work around the floor == -1 bug in some older DETX files
    floor_counter = 1
    last_string = -1
    floorminusone_warning_has_been_shown = false
  
    for mod ∈ 1:n_modules
        elements = split(lines[idx])
        module_id, string, floor = map(x->parse(Int, x), elements[1:3])

        # floor == -1 bug. We determine the floor position by assuming an ascending order
        # of modules in the DETX file
        if floor == -1
            if !floorminusone_warning_has_been_shown
                @warn "'Floor == -1' found in the detector file. The actual floor number will be inferred, assuming that modules and lines are sorted."
                floorminusone_warning_has_been_shown = true
            end
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


"""

Data structure for parameters of the mechanical model of strings. This data
structure is used to calculate the effective height conform to the mechanical
model of the string.

"""
struct StringMechanicsParameters
    a::Float64
    b::Float64
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

struct PMTData
    QE::Float64
    gain::Float64
    gainSpread::Float64
    riseTime_ns::Float64
    TTS_ns::Float64
    threshold::Float64
end

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
function read(filename::AbstractString, T::Type{PMTFile})
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
