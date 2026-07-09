# Jpp meta data (km3net-dataformat, JSupport/JMeta.hh): each application of a
# processing chain adds a `TNamed` to the top-level `META` directory, named after
# the application and with a "key=value" list (one per line) as its title.

const META_DIRECTORY = "META"
const META_NAME = "JMeta"

"""
Meta data of a single Jpp application, i.e. one step of the processing chain which
produced a [`ROOTFile`](@ref), available via its `meta` field.

The well-known entries are exposed as fields, the raw key-value pairs via indexing
(`m["GIT"]`), `keys`, `haskey` and `get`. `revision` is the `GIT` release, falling
back to `SVN` for legacy files.

`datetime` is the write time of the underlying ROOT key (local time of the writing
machine, `missing` if the file stores no valid timestamp). Every application copies
the meta data of its input, so all entries of a file usually carry the timestamp of
the step which created it.

`system` is the `uname` output, decomposed into `sysname`, `hostname`,
`kernel_release`, `kernel_datetime` and `machine`. Note that `kernel_datetime` is
the build time of the kernel and not a processing time.
"""
struct MetaData
    application::String
    revision::String
    root::String
    namespace::String
    command::String
    system::String
    sysname::String
    hostname::String
    kernel_release::String
    kernel_datetime::Union{DateTime, Missing}
    machine::String
    datetime::Union{DateTime, Missing}
    _raw::Dict{String, String}
end
function MetaData(raw::AbstractDict, datetime=missing)
    system = get(raw, "system", "")
    s = _parse_system(system)
    MetaData(
        get(raw, "application", ""),
        get(raw, "GIT", get(raw, "SVN", "")),
        get(raw, "ROOT", ""),
        get(raw, "namespace", ""),
        get(raw, "command", ""),
        system,
        s.sysname,
        s.hostname,
        s.kernel_release,
        s.kernel_datetime,
        s.machine,
        datetime,
        Dict{String, String}(raw),
    )
end

const _MONTH_NUMBERS = Dict(
    "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5, "Jun" => 6,
    "Jul" => 7, "Aug" => 8, "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12,
)

# Kernel build time in the `uname` version field, e.g. "#1 SMP Fri Dec 6 15:49:49
# UTC 2019". Matching starts at the month, which skips the weekday since only the
# month is followed by a day number. The timezone token is optional and discarded.
const _KERNEL_DATETIME = r"([A-Z][a-z]{2})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})(?:\s+[A-Za-z]{2,5})?\s+(\d{4})"

# `system` is "sysname nodename release version machine" (JUTSName). The version
# field contains spaces but always ends with the kernel build year, so `machine` is
# the token right after it. Some files store a full `uname -a`, with more tokens.
function _parse_system(system::AbstractString)
    tokens = split(system)
    n = length(tokens)
    sysname = n >= 1 ? String(tokens[1]) : ""
    hostname = n >= 2 ? String(tokens[2]) : ""
    kernel_release = n >= 3 ? String(tokens[3]) : ""
    kernel_datetime = missing
    machine = ""
    m = match(_KERNEL_DATETIME, system)
    if !isnothing(m)
        kernel_datetime = _kerneldatetime(m)
        yearidx = n >= 4 ? findnext(==(m.captures[6]), tokens, 4) : nothing
        if !isnothing(yearidx) && yearidx < n
            machine = String(tokens[yearidx + 1])
        end
    end
    (; sysname, hostname, kernel_release, kernel_datetime, machine)
end

function _kerneldatetime(m::RegexMatch)
    month = get(_MONTH_NUMBERS, m.captures[1], 0)
    try
        DateTime(
            parse(Int, m.captures[6]),
            month,
            parse(Int, m.captures[2]),
            parse(Int, m.captures[3]),
            parse(Int, m.captures[4]),
            parse(Int, m.captures[5]),
        )
    catch e
        e isa ArgumentError || rethrow()
        missing
    end
end

# ROOT's `TDatime`, a packed 32 bit word: bits 0-5 seconds, 6-11 minutes,
# 12-16 hours, 17-21 day, 22-25 month, 26-31 year since 1995.
function _datime2datetime(fDatime::Integer)
    d = UInt32(fDatime)
    year = Int(d >> 26) + 1995
    month = Int((d >> 22) & 0x0f)
    day = Int((d >> 17) & 0x1f)
    hour = Int((d >> 12) & 0x1f)
    minute = Int((d >> 6) & 0x3f)
    second = Int(d & 0x3f)
    try
        DateTime(year, month, day, hour, minute, second)
    catch e
        e isa ArgumentError || rethrow()
        missing
    end
end

Base.getindex(m::MetaData, key::AbstractString) = m._raw[key]
Base.get(m::MetaData, key::AbstractString, default) = get(m._raw, key, default)
Base.haskey(m::MetaData, key::AbstractString) = haskey(m._raw, key)
Base.keys(m::MetaData) = keys(m._raw)

function Base.show(io::IO, m::MetaData)
    rev = isempty(m.revision) ? "" : " @ $(m.revision)"
    print(io, "MetaData($(m.application)$(rev))")
end
function Base.show(io::IO, ::MIME"text/plain", m::MetaData)
    println(io, "MetaData ($(m.application))")
    println(io, "  datetime:  $(m.datetime)")
    println(io, "  revision:  $(m.revision)")
    println(io, "  ROOT:      $(m.root)")
    println(io, "  namespace: $(m.namespace)")
    println(io, "  hostname:  $(m.hostname)")
    println(io, "  system:    $(m.system)")
    print(io, "  command:   $(m.command)")
end

"""
Pretty-prints the application meta data in processing order (oldest first), one
block per application. Accepts a [`ROOTFile`](@ref), its `meta` vector, or a
single [`MetaData`](@ref), and writes to `io` (`stdout` by default).
"""
printmeta(m::MetaData) = printmeta(stdout, m)
printmeta(meta::AbstractVector{MetaData}) = printmeta(stdout, meta)
printmeta(io::IO, m::MetaData) = printmeta(io, [m])
function printmeta(io::IO, meta::AbstractVector{MetaData})
    n = length(meta)
    if n == 0
        println(io, "No meta data.")
        return nothing
    end
    println(io, "Meta data ($(n) processing step$(n == 1 ? "" : "s, oldest first"))")
    for (i, m) in enumerate(meta)
        println(io)
        println(io, "[$(i)] $(m.application)")
        println(io, "    datetime:  $(m.datetime)")
        println(io, "    revision:  $(m.revision)")
        println(io, "    ROOT:      $(m.root)")
        println(io, "    namespace: $(m.namespace)")
        println(io, "    hostname:  $(m.hostname)")
        println(io, "    system:    $(m.system)")
        println(io, "    command:   $(m.command)")
    end
    nothing
end

# Values may contain '=' themselves (command lines), so only the first '=' of a
# line separates key from value.
function _parse_jmeta(title::AbstractString)
    raw = Dict{String, String}()
    for line in split(title, '\n')
        isempty(line) && continue
        i = findfirst(isequal('='), line)
        isnothing(i) && continue
        key = String(line[firstindex(line):prevind(line, i)])
        raw[key] = String(line[nextind(line, i):end])
    end
    raw
end

"""
Reads the application meta data from the `META` directory of a ROOT file, ordered
by processing step (the first entry created the file). Empty if the file carries
no meta data.
"""
function readmeta(fobj::UnROOT.ROOTFile)
    idx = findfirst(
        k -> k.fName == META_DIRECTORY && k.fClassName == "TDirectory",
        fobj.directory.keys,
    )
    isnothing(idx) && return MetaData[]
    try
        _readmeta(fobj, fobj.directory.keys[idx])
    catch e
        # Meta data is auxiliary, but read eagerly: a corrupted META directory
        # must not render an otherwise readable file unopenable.
        @warn "Unable to read the META directory, continuing without meta data." exception=e
        MetaData[]
    end
end

function _readmeta(fobj::UnROOT.ROOTFile, metakey)
    metadir = UnROOT.TDirectory(fobj.fobj, metakey, fobj.directory.refs)
    appkeys = filter(
        k -> k.fClassName == "TNamed" && k.fName != META_NAME,
        metadir.keys,
    )
    # `fSeekKey` (byte offset) grows with each appended write and thus recovers the
    # processing order, regardless of ROOT cycles.
    sort!(appkeys, by = k -> k.fSeekKey)
    metadata = MetaData[]
    for k in appkeys
        raw = _parse_jmeta(k.fTitle)
        # Only JMeta records carry an application name, skip anything else.
        haskey(raw, "application") || continue
        push!(metadata, MetaData(raw, _datime2datetime(k.fDatime)))
    end
    metadata
end
