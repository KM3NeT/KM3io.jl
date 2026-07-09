# Application meta data written by Jpp (km3net-dataformat, JSupport/JMeta.hh).
# Each application in a processing chain stores a `TNamed` object inside the
# top-level `META` ROOT directory. The object's title is a "key=value" list
# (one entry per line) and its name is the application name. A parallel set of
# `JMeta` objects records the processing order.

const META_DIRECTORY = "META"
const META_NAME = "JMeta"

"""
Meta data of a single Jpp application (one step of a processing chain), as stored
via the `JMeta` mechanism of km3net-dataformat. A ROOT file usually carries one
`MetaData` entry per application which processed it, accessible through the `meta`
field of a [`ROOTFile`](@ref).

The well-known entries are exposed as fields. The raw key-value pairs as stored in
the file (including any non-standard keys) are reachable by indexing, e.g.
`m["GIT"]`, together with `keys`, `haskey` and `get`. Note that older files store
the code version under `SVN` instead of `GIT`; `revision` returns whichever is
present.

The `datetime` is the time at which the entry was written to the file, taken from
the timestamp of the underlying ROOT key. It is the local time of the writing
machine and carries no timezone information, and it is `missing` if the file
stores no valid timestamp. Since every application copies the meta data of its
input file into its own output, all entries of a file usually share the timestamp
of the processing step which created that file.

The `system` entry is the `uname` output of the machine which ran the application
and is decomposed into `sysname`, `hostname`, `kernel_release`, `kernel_datetime`
and `machine`. Note that `kernel_datetime` is the build time of the operating
system kernel, a property of the machine rather than of the processing step: all
jobs running on the same kernel report the very same value. Use `datetime` to find
out when a file was actually produced.
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

# The kernel build time as it appears in the `uname` version field, e.g.
# "#1 SMP Fri Dec 6 15:49:49 UTC 2019". The leading weekday is skipped implicitly
# since only the month name is followed by the day of month. The timezone token is
# optional and discarded, the resulting time is the one recorded in the string.
const _KERNEL_DATETIME = r"([A-Z][a-z]{2})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})(?:\s+[A-Za-z]{2,5})?\s+(\d{4})"

# Jpp assembles the `system` entry as "sysname nodename release version machine"
# (JUTSName). The version field itself contains spaces, but it always ends with
# the year of the kernel build time, so the machine is the token right after it.
# Some files instead store a full `uname -a`, which appends further tokens.
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

# ROOT stores the write time of a key as a packed 32 bit word (`TDatime`): bits
# 0-5 seconds, 6-11 minutes, 12-16 hours, 17-21 day, 22-25 month and 26-31 the
# year since 1995.
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

# Split a JMeta title ("key=value" lines) into its raw key-value pairs. The value
# may itself contain '=' (e.g. inside a command line), so only the first '=' of
# each line separates key from value.
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
Reads all application meta data from the `META` directory of a ROOT file and
returns them as a vector of [`MetaData`](@ref), ordered by processing step (the
first entry is the application which created the file). Returns an empty vector
if the file has no meta data.
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
        # The META directory is the only part of the file which is read eagerly
        # and it carries no event data. A truncated or corrupted one must not
        # render an otherwise perfectly readable file unopenable.
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
    # `fSeekKey` (byte offset in the file) grows with each appended write, so it
    # recovers the chronological processing order regardless of ROOT cycles.
    sort!(appkeys, by = k -> k.fSeekKey)
    metadata = MetaData[]
    for k in appkeys
        raw = _parse_jmeta(k.fTitle)
        # Every JMeta record stores the application name, anything else in this
        # directory does not originate from Jpp.
        haskey(raw, "application") || continue
        push!(metadata, MetaData(raw, _datime2datetime(k.fDatime)))
    end
    metadata
end
