function UnROOT.readtype(io, T::Type{SnapshotHit})
    T(UnROOT.readtype(io, Int32), read(io, UInt8), read(io, Int32), read(io, UInt8))
end
function UnROOT.interped_data(rawdata, rawoffsets, ::Type{Vector{SnapshotHit}}, ::Type{T}) where {T <: UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, SnapshotHit, skipbytes=10)
end

UnROOT.packedsizeof(::Type{TriggeredHit}) = 24  # incl. cnt and vers
function UnROOT.readtype(io, T::Type{TriggeredHit})
    dom_id = UnROOT.readtype(io, Int32)
    channel_id = read(io, UInt8)
    tdc = read(io, Int32)
    tot = read(io, UInt8)
    cnt = read(io, UInt32)
    vers = read(io, UInt16)
    trigger_mask = UnROOT.readtype(io, UInt64)
    T(dom_id, channel_id, tdc, tot, trigger_mask)
end
function UnROOT.interped_data(rawdata, rawoffsets, ::Type{Vector{TriggeredHit}}, ::Type{T}) where {T <: UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, TriggeredHit, skipbytes=10)
end

packedsizeof(::Type{EventHeader}) = 76
function UnROOT.readtype(io::IO, T::Type{EventHeader})
    skip(io, 18)
    detector_id = UnROOT.readtype(io, Int32)
    run = UnROOT.readtype(io, Int32)
    frame_index = UnROOT.readtype(io, Int32)
    skip(io, 6)
    UTC_seconds = UnROOT.readtype(io, UInt32)
    UTC_16nanosecondcycles = UnROOT.readtype(io, UInt32)
    skip(io, 6)
    trigger_counter = UnROOT.readtype(io, UInt64)
    skip(io, 6)
    trigger_mask = UnROOT.readtype(io, UInt64)
    overlays = UnROOT.readtype(io, UInt32)
    T(detector_id, run, frame_index, UTCExtended(UTC_seconds, UTC_16nanosecondcycles), trigger_counter, trigger_mask, overlays)
end
function UnROOT.interped_data(rawdata, rawoffsets, ::Type{EventHeader}, ::Type{T}) where {T <: UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, EventHeader, jagged=false)
end

function Base.show(io::IO, e::DAQEvent)
    print(io, "$(typeof(e)) with $(length(e.snapshot_hits)) snapshot and $(length(e.triggered_hits)) triggered hits")
end

struct EventContainer
    # For performance reasons we use the lazy types of UnROOT,
    # otherwise we have no laziness ;) We could also parametrise,
    # just like with SummarysliceContainer.
    headers::UnROOT.LazyBranch{EventHeader, UnROOT.Nojagg, Vector{EventHeader}}
    snapshot_hits::UnROOT.LazyBranch{Vector{SnapshotHit}, UnROOT.Nojagg, Vector{Vector{SnapshotHit}}}
    triggered_hits::UnROOT.LazyBranch{Vector{TriggeredHit}, UnROOT.Nojagg, Vector{Vector{TriggeredHit}}}
    # These were the original fields:
    # headers::Vector{EventHeader}
    # snapshot_hits::Vector{Vector{SnapshotHit}}
    # triggered_hits::Vector{Vector{TriggeredHit}}
end
Base.getindex(c::EventContainer, idx::Integer) = DAQEvent(c.headers[idx], c.snapshot_hits[idx], c.triggered_hits[idx])
Base.getindex(c::EventContainer, r::UnitRange) = [c[idx] for idx ∈ r]
Base.getindex(c::EventContainer, mask::BitArray) = [c[idx] for (idx, selected) ∈ enumerate(mask) if selected]
Base.length(c::EventContainer) = length(c.headers)
Base.size(c::EventContainer) = (length(c),)
Base.firstindex(c::EventContainer) = 1
Base.lastindex(c::EventContainer) = length(c)
Base.eltype(::EventContainer) = DAQEvent
function Base.iterate(c::EventContainer, state=1)
    state > length(c) ? nothing : (DAQEvent(c.headers[state], c.snapshot_hits[state], c.triggered_hits[state]), state+1)
end
function Base.show(io::IO, e::EventContainer)
    print(io, "$(typeof(e)) with $(length(e.headers)) events")
end

packedsizeof(::Type{SummarysliceHeader}) = 44
function UnROOT.readtype(io::IO, T::Type{SummarysliceHeader})
    skip(io, 18)
    detector_id = UnROOT.readtype(io, Int32)
    run = UnROOT.readtype(io, Int32)
    frame_index = UnROOT.readtype(io, Int32)
    skip(io, 6)
    UTC_seconds = UnROOT.readtype(io, UInt32)
    UTC_16nanosecondcycles = UnROOT.readtype(io, UInt32)
    T(detector_id, run, frame_index, UTCExtended(UTC_seconds, UTC_16nanosecondcycles))
end
function UnROOT.interped_data(rawdata, rawoffsets, ::Type{SummarysliceHeader}, ::Type{T}) where {T <: UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, SummarysliceHeader, jagged=false)
end

UnROOT.packedsizeof(::Type{SummaryFrame}) = 55  # incl. cnt and vers
function UnROOT.readtype(io, T::Type{SummaryFrame})
    dom_id = UnROOT.readtype(io, Int32)
    daq = UnROOT.readtype(io, UInt32)
    status = UnROOT.readtype(io, UInt32)
    fifo = UnROOT.readtype(io, UInt32)
    status3 = UnROOT.readtype(io, UInt32)
    status4 = UnROOT.readtype(io, UInt32)
    rates = [UnROOT.read(io, UInt8) for i ∈ 1:31]
    # burn one byte
    #read(io, UInt8)
    T(dom_id, daq, status, fifo, status3, status4, rates)
end
function UnROOT.interped_data(rawdata, rawoffsets, ::Type{Vector{SummaryFrame}}, ::Type{T}) where {T <: UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, SummaryFrame, skipbytes=10)
end
"""

A summaryslice is a condensed timeslice with the header information of the
corresponding timeslice and a summary frame for each optical module. The hit
information of the original timeslice is reduced so that for each PMT a
single byte is used to encode the hit rate.

"""
struct Summaryslice
    header::SummarysliceHeader
    frames::Vector{SummaryFrame}
end
function Base.show(io::IO, s::Summaryslice)
    print(io, "Summaryslice($(length(s.frames)) frames)")
end
struct SummarysliceContainer
    # For performance reasons we use directly the lazy types of UnROOT
    # We could also parametrise it.
    # Originally this was headers::Vector{SummarysliceHeader} and
    # summaryslices::Vector{Vector{SummaryFrame}}
    headers::UnROOT.LazyBranch{SummarysliceHeader, UnROOT.Nojagg, Vector{SummarysliceHeader}}
    summaryslices::UnROOT.LazyBranch{Vector{SummaryFrame}, UnROOT.Nojagg, Vector{Vector{SummaryFrame}}}
end

Base.getindex(c::SummarysliceContainer, idx::Integer) = Summaryslice(c.headers[idx], c.summaryslices[idx])
Base.getindex(c::SummarysliceContainer, r::UnitRange) = [c[idx] for idx ∈ r]
Base.getindex(c::SummarysliceContainer, mask::BitArray) = [c[idx] for (idx, selected) ∈ enumerate(mask) if selected]
Base.length(c::SummarysliceContainer) = length(c.headers)
Base.size(c::SummarysliceContainer) = (length(c),)
Base.firstindex(c::SummarysliceContainer) = 1
Base.lastindex(c::SummarysliceContainer) = length(c)
Base.eltype(::SummarysliceContainer) = Summaryslice
function Base.iterate(c::SummarysliceContainer, state=1)
    state > length(c) ? nothing : (c[state], state+1)
end
function Base.show(io::IO, c::SummarysliceContainer)
    print(io, "$(typeof(c)) with $(length(c.headers)) summaryslices")
end


# Timeslices
#
# A timeslice (`KM3NETDAQ::JDAQTimeslice` and its `L0`/`L1`/`L2`/`SN` subclasses)
# is, just like a summaryslice, a 100 ms data taking period. In contrast to the
# summaryslice -- which only keeps a single rate byte per PMT -- a timeslice
# stores every individual hit, grouped per optical module into super frames
# (`KM3NETDAQ::JDAQSuperFrame`).
#
# The streams differ in their ROOT split level (see the dataformat `root.csv`),
# which changes how a timeslice is laid out on disk. Three layouts are supported:
#
#   * member-wise blob (split level 2, modern files): the header
#     `KM3NETDAQ::JDAQChronometer` is unrolled into the scalar leaves
#     `detector_id`, `run`, `frame_index` plus a `timeslice_start` object leaf,
#     while the `vector<KM3NETDAQ::JDAQSuperFrame>` is a single branch holding the
#     whole member-wise streamed collection, decoded by `_parse_superframes`.
#   * fully split (split level 2, older files): the `vector<...>` is unrolled into
#     one sub-branch per data member (`.id`, `.numberOfHits`, `.daq`, ...,
#     `.buffer`) and `timeslice_start` is split into
#     `UTC_seconds`/`UTC_16nanosecondcycles` leaves. This is handled by the
#     `_SplitFrameReader` further below.
#   * unsplit header (split level 1, the bare `KM3NET_TIMESLICE` tree): the whole
#     `KM3NETDAQ::JDAQTimesliceHeader` is a single object leaf, the super frames
#     are the member-wise blob.
#
# The strategy types `_TimesliceHeaderReader`, `_TimesliceTimeReader` and
# `_SuperFrameReader` abstract over these so that the public container interface
# stays identical.

# The bare `KM3NET_TIMESLICE` tree is written with split level 1 (the other
# streams use 2), which leaves the `KM3NETDAQ::JDAQTimesliceHeader` as a single
# unsplit 44 byte object leaf instead of unrolling it into scalar leaves. The
# blob holds the object headers (byte count + class version) of the three nested
# base classes, the chronometer and the timeslice start:
#
#     JDAQTimesliceHeader  6 byte
#     JDAQHeader           6 byte
#     JDAQChronometer      6 byte
#     detector_id          Int32
#     run                  Int32
#     frame_index          Int32
#     timeslice_start      6 byte object header + 2 x UInt32
#
# which is the same layout as the `JDAQSummarysliceHeader`, since both derive
# from `JDAQChronometer` via `JDAQHeader`.
packedsizeof(::Type{TimesliceHeader}) = 44
function UnROOT.readtype(io::IO, T::Type{TimesliceHeader})
    skip(io, 18)
    detector_id = UnROOT.readtype(io, Int32)
    run = UnROOT.readtype(io, Int32)
    frame_index = UnROOT.readtype(io, Int32)
    skip(io, 6)
    UTC_seconds = UnROOT.readtype(io, UInt32)
    UTC_16nanosecondcycles = UnROOT.readtype(io, UInt32)
    T(detector_id, run, frame_index, UTCExtended(UTC_seconds, UTC_16nanosecondcycles))
end
function UnROOT.interped_data(rawdata, rawoffsets, ::Type{TimesliceHeader}, ::Type{T}) where {T<:UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, TimesliceHeader, jagged=false)
end

# The `timeslice_start` (a `KM3NETDAQ::JDAQUTCExtended`) is stored as its own
# split leaf: a 6 byte object header (byte count + version) followed by the two
# 32 bit words. Reading it requires a custom streamer since UnROOT cannot infer
# the type of the bare object leaf.
function UnROOT.readtype(io::IO, T::Type{UTCExtended})
    skip(io, 6)  # fByteCount (4) + fVersion (2)
    s = UnROOT.readtype(io, UInt32)
    cycles = UnROOT.readtype(io, UInt32)
    UTCExtended(s, cycles)
end
function UnROOT.interped_data(rawdata, rawoffsets, ::Type{UTCExtended}, ::Type{T}) where {T<:UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, UTCExtended, jagged=false)
end

"""

Decode the member-wise streamed `vector<KM3NETDAQ::JDAQSuperFrame>` branch of a
timeslice into a `Vector{SuperFrame}` for each entry.

The collection is streamed member-wise (columnar): after a 12 byte header
(`fByteCount`, the member-wise `fVersion`, the `JDAQSuperFrame` class version and
the number of super frames `n`) each data member is stored contiguously for all
`n` super frames, following the streamer (base class) order:

    JDAQPreamble.length          n x Int32
    JDAQPreamble.type            n x Int32   (= DAQSUPERFRAME)
    TObject                      n x 10 byte (version + fUniqueID + fBits)
    JDAQChronometer.detector_id  n x Int32   (redundant with the header)
    JDAQChronometer.run          n x Int32
    JDAQChronometer.frame_index  n x Int32
    JDAQChronometer.timeslice_start  n x 14 byte (JDAQUTCExtended object)
    JDAQModuleIdentifier.id      n x Int32   (the module id)
    JDAQFrameStatus.daq          n x UInt32
    JDAQFrameStatus.status       n x UInt32
    JDAQFrameStatus.fifo         n x UInt32
    JDAQFrameStatus.status_3     n x Int32   (spare)
    JDAQFrameStatus.status_4     n x Int32   (spare)
    JDAQFrame.numberOfHits       n x Int32
    JDAQFrame.buffer             6 byte header + concatenated hits

Each hit occupies 6 bytes: `pmt` (UInt8), `tdc` (UInt32, little-endian) and
`tot` (UInt8).

"""
function _parse_superframes(rawdata::Vector{UInt8}, rawoffsets)
    nentries = length(rawoffsets) - 1
    out = Vector{Vector{SuperFrame}}(undef, nentries)
    io = IOBuffer(rawdata)
    @inbounds for e in 1:nentries
        seek(io, rawoffsets[e])
        skip(io, 4)                              # fByteCount
        version = UnROOT.readtype(io, UInt16)    # collection streamer version
        if (version & 0x4000) == 0
            error("Timeslice super frames are not streamed member-wise " *
                  "(version=0x$(string(version, base=16))); this layout is not supported.")
        end
        skip(io, 2)                              # JDAQSuperFrame class version
        n = UnROOT.readtype(io, Int32)           # number of super frames
        n < 0 && error("Corrupt timeslice: negative super frame count ($n)")
        # member-wise columns (each with `n` elements), in streamer order
        skip(io, 4n)                             # JDAQPreamble.length
        skip(io, 4n)                             # JDAQPreamble.type
        skip(io, 10n)                            # TObject
        skip(io, 4n)                             # detector_id (redundant with header)
        skip(io, 4n)                             # run
        skip(io, 4n)                             # frame_index
        skip(io, 14n)                            # timeslice_start (JDAQUTCExtended)
        module_ids = Vector{Int32}(undef, n)
        for i in 1:n; module_ids[i] = UnROOT.readtype(io, Int32); end
        daq = Vector{UInt32}(undef, n)
        for i in 1:n; daq[i] = UnROOT.readtype(io, UInt32); end
        status = Vector{UInt32}(undef, n)
        for i in 1:n; status[i] = UnROOT.readtype(io, UInt32); end
        fifo = Vector{UInt32}(undef, n)
        for i in 1:n; fifo[i] = UnROOT.readtype(io, UInt32); end
        skip(io, 4n)                             # status_3 (spare)
        skip(io, 4n)                             # status_4 (spare)
        nhits = Vector{Int32}(undef, n)
        for i in 1:n; nhits[i] = UnROOT.readtype(io, Int32); end
        skip(io, 6)                              # buffer fByteCount (4) + fVersion (2)
        frames = Vector{SuperFrame}(undef, n)
        for i in 1:n
            m = nhits[i]
            hits = Vector{TimesliceHit}(undef, m)
            for j in 1:m
                pmt = read(io, UInt8)
                tdc = ltoh(read(io, UInt32))     # little-endian on disk
                tot = read(io, UInt8)
                hits[j] = TimesliceHit(tdc % Int32, pmt, tot)
            end
            frames[i] = SuperFrame(module_ids[i], daq[i], status[i], fifo[i], hits)
        end
        out[e] = frames
    end
    out
end
function UnROOT.interped_data(rawdata, rawoffsets, ::Type{Vector{SuperFrame}}, ::Type{T}) where {T<:UnROOT.JaggType}
    _parse_superframes(rawdata, rawoffsets)
end

"""

A timeslice: the data acquisition snapshot of a 100 ms time window holding all
the hits of each participating optical module, grouped into [`SuperFrame`](@ref)s.

"""
struct Timeslice
    header::TimesliceHeader
    frames::Vector{SuperFrame}
    stream::Symbol
end
function Base.show(io::IO, ts::Timeslice)
    nhits = sum(f -> length(f.hits), ts.frames; init=0)
    print(io, "$(ts.stream)-Timeslice with $(length(ts.frames)) frames and $(nhits) hits")
end
# Concise show methods, otherwise a single super frame would dump all of its hits.
Base.show(io::IO, f::SuperFrame) = print(io, "SuperFrame(module $(f.module_id), $(length(f.hits)) hits)")
Base.show(io::IO, h::TimesliceHit) = print(io, "TimesliceHit(channel_id=$(Int(h.channel_id)), t=$(h.t), tot=$(Int(h.tot)))")

const _TIMESLICE_VECTOR_BRANCH = "vector<KM3NETDAQ::JDAQSuperFrame>"

# Recursively search the branch tree for a (sub-)branch with the given name. This
# is robust against the different nesting depths produced by the various split
# levels of the timeslice trees.
function _find_branch(branch, name)
    (hasproperty(branch, :fName) && branch.fName == name) && return branch
    if hasproperty(branch, :fBranches)
        for subbranch in branch.fBranches.elements
            result = _find_branch(subbranch, name)
            result === nothing || return result
        end
    end
    nothing
end
function _find_branch(tree::UnROOT.TTree, name)
    for branch in tree.fBranches.elements
        result = _find_branch(branch, name)
        result === nothing || return result
    end
    nothing
end

# Depending on the ROOT split level a timeslice was written with, the super
# frames live in one of two on-disk layouts and the header time in one of two
# encodings. The strategy types below abstract over these so that the public
# `TimesliceContainer`/`Timeslice` interface stays the same.

# The strategy types are parametrised over the concrete `UnROOT.LazyBranch` types
# they hold so that the lazy-branch field accesses (and hence indexing into a
# `TimesliceContainer`) stay type-stable.

# --- header time readers ---
abstract type _TimesliceTimeReader end
# `timeslice_start` stored as a single (member-wise streamed) object leaf
struct _TimesliceTimeObject{T<:UnROOT.LazyBranch} <: _TimesliceTimeReader
    _t::T
end
_readtime(r::_TimesliceTimeObject, idx::Integer) = r._t[idx]
# `timeslice_start` split into two scalar leaves (fully split trees)
struct _TimesliceTimeSplit{S<:UnROOT.LazyBranch, C<:UnROOT.LazyBranch} <: _TimesliceTimeReader
    _seconds::S
    _cycles::C
end
_readtime(r::_TimesliceTimeSplit, idx::Integer) = UTCExtended(r._seconds[idx], r._cycles[idx])

# --- header readers ---
abstract type _TimesliceHeaderReader end

# Split header: the chronometer is unrolled into scalar leaves.
struct _SplitHeaderReader{D<:UnROOT.LazyBranch, R<:UnROOT.LazyBranch, FI<:UnROOT.LazyBranch, TR<:_TimesliceTimeReader} <: _TimesliceHeaderReader
    _detector_id::D
    _run::R
    _frame_index::FI
    _time::TR
end
_readheader(r::_SplitHeaderReader, idx::Integer) =
    TimesliceHeader(r._detector_id[idx], r._run[idx], r._frame_index[idx], _readtime(r._time, idx))
Base.length(r::_SplitHeaderReader) = length(r._detector_id)

# Unsplit header: a single object leaf, decoded by the `TimesliceHeader` streamer.
struct _ObjectHeaderReader{H<:UnROOT.LazyBranch} <: _TimesliceHeaderReader
    _header::H
end
_readheader(r::_ObjectHeaderReader, idx::Integer) = r._header[idx]
Base.length(r::_ObjectHeaderReader) = length(r._header)

# --- super frame readers ---
abstract type _SuperFrameReader end

# Member-wise blob layout: the whole `vector<JDAQSuperFrame>` is a single branch
# decoded per entry by `_parse_superframes` (via the custom `interped_data`).
struct _MemberwiseFrameReader{F<:UnROOT.LazyBranch} <: _SuperFrameReader
    _frames::F
end
_readframes(r::_MemberwiseFrameReader, idx::Integer) = r._frames[idx]

# Fully split layout: each data member is a separate sub-branch. The hits live in
# the `.buffer` sub-branch, a `TStreamerLoop` which UnROOT cannot interpret on its
# own, so it is read raw (lazily, then cached) and partitioned into frames using
# the per-frame `.numberOfHits`.
mutable struct _SplitFrameReader{M<:UnROOT.LazyBranch, N<:UnROOT.LazyBranch, D<:UnROOT.LazyBranch, S<:UnROOT.LazyBranch, F<:UnROOT.LazyBranch} <: _SuperFrameReader
    _fobj::UnROOT.ROOTFile
    _module_id::M
    _numberOfHits::N
    _daq::D
    _status::S
    _fifo::F
    _buffer_branch::UnROOT.TBranchElement
    _buffer_raw::Union{Nothing, Tuple{Vector{UInt8}, Vector{Int32}}}
    _lock::ReentrantLock
end
function _readframes(r::_SplitFrameReader, idx::Integer)
    if isnothing(r._buffer_raw)
        lock(r._lock) do
            isnothing(r._buffer_raw) && (r._buffer_raw = UnROOT.array(r._fobj, r._buffer_branch; raw=true))
        end
    end
    bufdata, bufoffsets = r._buffer_raw
    module_ids = r._module_id[idx]
    counts = r._numberOfHits[idx]
    daq = r._daq[idx]; status = r._status[idx]; fifo = r._fifo[idx]
    n = length(module_ids)
    frames = Vector{SuperFrame}(undef, n)
    io = IOBuffer(bufdata)
    seek(io, bufoffsets[idx])
    skip(io, 6)  # per-entry buffer header (fByteCount + fVersion)
    @inbounds for k in 1:n
        m = Int(counts[k])
        hits = Vector{TimesliceHit}(undef, m)
        for j in 1:m
            pmt = read(io, UInt8)
            tdc = ltoh(read(io, UInt32))  # little-endian on disk
            tot = read(io, UInt8)
            hits[j] = TimesliceHit(tdc % Int32, pmt, tot)
        end
        frames[k] = SuperFrame(module_ids[k], reinterpret(UInt32, daq[k]),
                               reinterpret(UInt32, status[k]), reinterpret(UInt32, fifo[k]), hits)
    end
    frames
end

function _timeslice_time_reader(fobj::UnROOT.ROOTFile, header)
    tb = _find_branch(header, "timeslice_start")
    isnothing(tb) || return _TimesliceTimeObject(UnROOT.LazyBranch(fobj, tb))
    seconds = _find_branch(header, "timeslice_start.UTC_seconds")
    cycles = _find_branch(header, "timeslice_start.UTC_16nanosecondcycles")
    _TimesliceTimeSplit(UnROOT.LazyBranch(fobj, seconds), UnROOT.LazyBranch(fobj, cycles))
end

function _timeslice_header_reader(fobj::UnROOT.ROOTFile, header)
    isempty(header.fBranches.elements) && return _ObjectHeaderReader(UnROOT.LazyBranch(fobj, header))
    _SplitHeaderReader(
        UnROOT.LazyBranch(fobj, _find_branch(header, "detector_id")),
        UnROOT.LazyBranch(fobj, _find_branch(header, "run")),
        UnROOT.LazyBranch(fobj, _find_branch(header, "frame_index")),
        _timeslice_time_reader(fobj, header),
    )
end

function _superframe_reader(fobj::UnROOT.ROOTFile, tree::UnROOT.TTree)
    vbranch = _find_branch(tree, _TIMESLICE_VECTOR_BRANCH)
    isempty(vbranch.fBranches.elements) &&
        return _MemberwiseFrameReader(UnROOT.LazyBranch(fobj, vbranch))
    sub(name) = UnROOT.LazyBranch(fobj, _find_branch(vbranch, "$(_TIMESLICE_VECTOR_BRANCH).$(name)"))
    _SplitFrameReader(
        fobj,
        sub("id"), sub("numberOfHits"), sub("daq"), sub("status"), sub("fifo"),
        _find_branch(vbranch, "$(_TIMESLICE_VECTOR_BRANCH).buffer"),
        nothing, ReentrantLock(),
    )
end

"""

A lazy container for the timeslices of a single stream (`:L0`, `:L1`, `:L2`,
`:SN` or `:TS`). Timeslices are read on demand via indexing or iteration.

"""
struct TimesliceContainer{H<:_TimesliceHeaderReader, FR<:_SuperFrameReader}
    stream::Symbol
    _header::H
    _frames::FR
end
function TimesliceContainer(fobj::UnROOT.ROOTFile, tree::UnROOT.TTree, stream::Symbol)
    header = _find_branch(tree, "KM3NETDAQ::JDAQTimesliceHeader")
    TimesliceContainer(stream, _timeslice_header_reader(fobj, header), _superframe_reader(fobj, tree))
end
Base.length(c::TimesliceContainer) = length(c._header)
Base.size(c::TimesliceContainer) = (length(c),)
Base.firstindex(c::TimesliceContainer) = 1
Base.lastindex(c::TimesliceContainer) = length(c)
Base.eltype(::TimesliceContainer) = Timeslice
function Base.getindex(c::TimesliceContainer, idx::Integer)
    Timeslice(_readheader(c._header, idx), _readframes(c._frames, idx), c.stream)
end
Base.getindex(c::TimesliceContainer, r::UnitRange) = [c[idx] for idx ∈ r]
Base.getindex(c::TimesliceContainer, mask::BitArray) = [c[idx] for (idx, selected) ∈ enumerate(mask) if selected]
function Base.iterate(c::TimesliceContainer, state=1)
    state > length(c) ? nothing : (c[state], state+1)
end
function Base.show(io::IO, c::TimesliceContainer)
    print(io, "$(c.stream)-TimesliceContainer with $(length(c)) timeslices")
end

"""

The timeslice streams of an online file. Each field is either a
[`TimesliceContainer`](@ref) or `nothing` if the corresponding stream is absent
or empty. The L0 stream is unfiltered, L1 and L2 contain (loosely and tightly)
coincident hits and SN holds the supernova trigger stream.

The TS stream is the bare `KM3NET_TIMESLICE` tree, which in run files holds the
super frames that the data filter rejected (see [`checksum`](@ref)) and excluded
from the other streams, so it is complementary to them and not physics data.

"""
struct Timeslices
    L0::Union{TimesliceContainer, Nothing}
    L1::Union{TimesliceContainer, Nothing}
    L2::Union{TimesliceContainer, Nothing}
    SN::Union{TimesliceContainer, Nothing}
    TS::Union{TimesliceContainer, Nothing}
end
function Timeslices(fobj::UnROOT.ROOTFile)
    keyset = keys(fobj)
    function build(treename, stream)
        treename ∈ keyset || return nothing
        tree = fobj[treename]
        tree.fEntries == 0 && return nothing
        header = _find_branch(tree, "KM3NETDAQ::JDAQTimesliceHeader")
        vbranch = _find_branch(tree, _TIMESLICE_VECTOR_BRANCH)
        (isnothing(header) || isnothing(vbranch)) && return nothing
        if isempty(header.fBranches.elements)
            # an unsplit header only ever comes with the member-wise super frames,
            # anything else is a layout we do not know
            isempty(vbranch.fBranches.elements) || return nothing
        else
            # a split header must provide detector id, run, frame index and a timeslice start
            _find_branch(header, "detector_id") === nothing && return nothing
            has_time = _find_branch(header, "timeslice_start") !== nothing ||
                       _find_branch(header, "timeslice_start.UTC_seconds") !== nothing
            has_time || return nothing
        end
        # a fully split vector needs all the sub-branches we read by name
        if !isempty(vbranch.fBranches.elements)
            for name ∈ ("id", "numberOfHits", "daq", "status", "fifo", "buffer")
                _find_branch(vbranch, "$(_TIMESLICE_VECTOR_BRANCH).$(name)") === nothing && return nothing
            end
        end
        TimesliceContainer(fobj, tree, stream)
    end
    Timeslices(
        build(ROOT.TTREE_ONLINE_TIMESLICEL0, :L0),
        build(ROOT.TTREE_ONLINE_TIMESLICEL1, :L1),
        build(ROOT.TTREE_ONLINE_TIMESLICEL2, :L2),
        build(ROOT.TTREE_ONLINE_TIMESLICESN, :SN),
        build(ROOT.TTREE_ONLINE_TIMESLICE, :TS),
    )
end
const TIMESLICE_STREAMS = (:L0, :L1, :L2, :SN, :TS)
function Base.show(io::IO, t::Timeslices)
    parts = String[]
    for stream ∈ TIMESLICE_STREAMS
        c = getproperty(t, stream)
        isnothing(c) || push!(parts, "$(length(c)) $(stream)")
    end
    if isempty(parts)
        print(io, "Timeslices (none)")
    else
        print(io, "Timeslices ($(join(parts, ", ")))")
    end
end


struct OnlineTree
    _fobj::UnROOT.ROOTFile
    events::Union{EventContainer, Nothing}
    summaryslices::Union{SummarysliceContainer, Nothing}
    timeslices::Timeslices
    _frame_index_trigger_counter_lookup_map::Dict{Tuple{Int, Int}, Int}
    _timeorders::Dict{Symbol, Vector{Int}}
    _lock::ReentrantLock

    function OnlineTree(fobj::UnROOT.ROOTFile)
        keyset = keys(fobj)
        events = ROOT.TTREE_ONLINE_EVENT ∈ keyset ?
            EventContainer(
                UnROOT.LazyBranch(fobj, "KM3NET_EVENT/KM3NET_EVENT/KM3NETDAQ::JDAQEventHeader"),
                UnROOT.LazyBranch(fobj, "KM3NET_EVENT/KM3NET_EVENT/snapshotHits"),
                UnROOT.LazyBranch(fobj, "KM3NET_EVENT/KM3NET_EVENT/triggeredHits"),
            ) : nothing
        summaryslices = ROOT.TTREE_ONLINE_SUMMARYSLICE ∈ keyset ?
            SummarysliceContainer(
                UnROOT.LazyBranch(fobj, "KM3NET_SUMMARYSLICE/KM3NET_SUMMARYSLICE/KM3NETDAQ::JDAQSummarysliceHeader"),
                UnROOT.LazyBranch(fobj, "KM3NET_SUMMARYSLICE/KM3NET_SUMMARYSLICE/vector<KM3NETDAQ::JDAQSummaryFrame>")
            ) : nothing
        timeslices = Timeslices(fobj)
        new(fobj, events, summaryslices, timeslices, Dict{Tuple{Int, Int}, Int}(),
            Dict{Symbol, Vector{Int}}(), ReentrantLock())
    end
end
function Base.show(io::IO, t::OnlineTree)
    parts = String[]
    isnothing(t.events) || push!(parts, "$(length(t.events)) events")
    isnothing(t.summaryslices) || push!(parts, "$(length(t.summaryslices)) summaryslices")
    for stream ∈ TIMESLICE_STREAMS
        c = getproperty(t.timeslices, stream)
        isnothing(c) || push!(parts, "$(length(c)) $(stream)-timeslices")
    end
    print(io, "OnlineTree ($(join(parts, ", ")))")
end

# Time ordering
#
# The DAQ writes events, summaryslices and timeslices in the order in which the
# data filter processed them, which is not their order in time. The `timesorted`
# keyword of the `each*` iterators hands them over in time order instead.
#
# The permutation is derived from the header alone: only the branches holding the
# time of each entry are read, never the payload branches with the hits, which are
# orders of magnitude larger. It is then cached in the tree, so that it is
# computed at most once per stream, no matter how often the iterators are created.

_nanoseconds(t::UTCExtended) = UInt64(t.s) * 1_000_000_000 + t.ns

# the timeslice header readers can hand out the time without reading the rest of
# the header (the split one keeps it in its own branch)
_readtimestamp(r::_SplitHeaderReader, idx::Integer) = _readtime(r._time, idx)
_readtimestamp(r::_ObjectHeaderReader, idx::Integer) = r._header[idx].t

_timestamps(c::EventContainer) = UInt64[_nanoseconds(h.t) for h ∈ c.headers]
_timestamps(c::SummarysliceContainer) = UInt64[_nanoseconds(h.t) for h ∈ c.headers]
_timestamps(c::TimesliceContainer) = UInt64[_nanoseconds(_readtimestamp(c._header, idx)) for idx ∈ 1:length(c)]

# A stable sort, so that entries which share a header time (all the events of a
# single timeslice do) keep the order in which they were written.
_timesortperm(c) = sortperm(_timestamps(c); alg=MergeSort)

# The cached time order of a stream, computed on first use. `nothing` for an
# absent stream, so that it can be passed straight to a view.
_timeorder(t::OnlineTree, key::Symbol, ::Nothing) = nothing
function _timeorder(t::OnlineTree, key::Symbol, container)
    lock(t._lock) do
        get!(() -> _timesortperm(container), t._timeorders, key)
    end
end

# The entry to read for the `idx`-th element of a view, which is `idx` itself
# unless the view carries a permutation.
const _Order = Union{Nothing, Vector{Int}}
_entry(::Nothing, idx::Integer) = idx
_entry(order::Vector{Int}, idx::Integer) = order[idx]

# Online counterpart of eachevent. A plain wrapper for now (no branch skipping),
# provided so the same verb works for online and offline trees.
struct OnlineTreeView
    _tree::OnlineTree
    _order::_Order
end

"""
    eachevent(t::OnlineTree; timesorted=false)

An iterable, index-able view over the DAQ events of an online tree. With
`timesorted`, the events are handed over in the order of their header time rather
than in the order in which they were written, see [`eachtimeslice`](@ref).
"""
eachevent(t::OnlineTree; timesorted=false) =
    OnlineTreeView(t, timesorted ? _timeorder(t, :events, t.events) : nothing)

_eventcontainer(v::OnlineTreeView) = v._tree.events
Base.length(v::OnlineTreeView) = (c = _eventcontainer(v); isnothing(c) ? 0 : length(c))
Base.size(v::OnlineTreeView) = (length(v),)
Base.firstindex(v::OnlineTreeView) = 1
Base.lastindex(v::OnlineTreeView) = length(v)
Base.eltype(::OnlineTreeView) = DAQEvent
Base.getindex(v::OnlineTreeView, idx::Integer) = _eventcontainer(v)[_entry(v._order, idx)]
Base.getindex(v::OnlineTreeView, r::UnitRange) = [v[idx] for idx ∈ r]
Base.getindex(v::OnlineTreeView, mask::BitArray) = [v[idx] for (idx, selected) ∈ enumerate(mask) if selected]
function Base.iterate(v::OnlineTreeView, state=1)
    state > length(v) ? nothing : (v[state], state+1)
end
function Base.show(io::IO, v::OnlineTreeView)
    print(io, "OnlineTreeView ($(length(v)) events)")
end

struct SummarysliceView{C<:Union{SummarysliceContainer, Nothing}}
    _container::C
    _order::_Order
end

"""
    eachsummaryslice(t::OnlineTree; timesorted=false)
    eachsummaryslice(f::ROOTFile; timesorted=false)

An iterable, index-able view over the summaryslices, the counterpart of
[`eachevent`](@ref) for the summaryslice tree. A file without summaryslices simply
yields nothing, so no guard is needed.

With `timesorted`, the summaryslices are handed over in the order of their header
time rather than in the order in which they were written, see
[`eachtimeslice`](@ref).

# Example
```
julia> f = ROOTFile(datapath("online", "km3net_online.root"));

julia> for s ∈ eachsummaryslice(f; timesorted=true)
           @show s.header.frame_index, length(s.frames)
       end
```
"""
eachsummaryslice(t::OnlineTree; timesorted=false) =
    SummarysliceView(t.summaryslices, timesorted ? _timeorder(t, :summaryslices, t.summaryslices) : nothing)

Base.length(::SummarysliceView{Nothing}) = 0
Base.length(v::SummarysliceView) = length(v._container)
Base.size(v::SummarysliceView) = (length(v),)
Base.firstindex(v::SummarysliceView) = 1
Base.lastindex(v::SummarysliceView) = length(v)
Base.eltype(::SummarysliceView) = Summaryslice
Base.getindex(v::SummarysliceView, idx::Integer) = v._container[_entry(v._order, idx)]
Base.getindex(v::SummarysliceView, r::UnitRange) = [v[idx] for idx ∈ r]
Base.getindex(v::SummarysliceView, mask::BitArray) = [v[idx] for (idx, selected) ∈ enumerate(mask) if selected]
function Base.iterate(v::SummarysliceView, state=1)
    state > length(v) ? nothing : (v[state], state+1)
end
function Base.show(io::IO, v::SummarysliceView)
    print(io, "SummarysliceView ($(length(v)) summaryslices)")
end

# Whether a timeslice has at least one super frame of one of the given optical
# modules. The fully split layout keeps the module ids in their own branch, so
# they can be checked without touching the hits, which are by far the bulk of a
# timeslice. The member-wise layout stores everything in a single branch, so the
# timeslice has to be decoded either way (the decoded basket is cached by UnROOT,
# so reading a matching timeslice afterwards is free).
_hasmodule(r::_SplitFrameReader, idx::Integer, module_ids) = any(∈(module_ids), r._module_id[idx])
_hasmodule(r::_MemberwiseFrameReader, idx::Integer, module_ids) =
    any(frame -> frame.module_id ∈ module_ids, r._frames[idx])

struct TimesliceView{C<:Union{TimesliceContainer, Nothing}}
    _container::C
    module_ids::Set{Int32}
    _order::_Order
end
Base.eltype(::TimesliceView) = Timeslice
Base.IteratorSize(::Type{<:TimesliceView}) = Base.SizeUnknown()
Base.iterate(::TimesliceView{Nothing}, state=1) = nothing
function Base.iterate(v::TimesliceView{<:TimesliceContainer}, state=1)
    c = v._container
    while state <= length(c)
        idx = _entry(v._order, state)
        if isempty(v.module_ids) || _hasmodule(c._frames, idx, v.module_ids)
            return (c[idx], state + 1)
        end
        state += 1
    end
    nothing
end
function Base.show(io::IO, v::TimesliceView{Nothing})
    print(io, "TimesliceView (empty)")
end
function Base.show(io::IO, v::TimesliceView{<:TimesliceContainer})
    filtered = isempty(v.module_ids) ? "" : ", filtered by $(length(v.module_ids)) module(s)"
    print(io, "TimesliceView ($(v._container.stream), $(length(v._container)) timeslices$(filtered))")
end

"""
    eachtimeslice(t::OnlineTree, stream::Symbol; module_ids=(), timesorted=false)
    eachtimeslice(f::ROOTFile, stream::Symbol; module_ids=(), timesorted=false)

An iterable view over the timeslices of a single `stream` (`:L0`, `:L1`, `:L2`,
`:SN` or `:TS`), the online counterpart of [`eachevent`](@ref) for timeslices. A
stream which is absent or empty simply yields nothing, so no guard is needed.

The DAQ writes the entries of a tree in the order in which the data filter
processed them, which is not their order in time. With `timesorted`, they are
handed over sorted by their header time instead. The permutation is derived from
the header branches alone, without ever reading the hits, and it is cached in the
tree, so it is computed at most once per stream.

`module_ids` restricts the iteration to the timeslices which have at least one
super frame of one of the given optical modules; all others are skipped. The
frames of a yielded timeslice are not filtered. This mostly pays off for the `:TS`
stream, where a timeslice usually holds a single module, while the L0, L1, L2 and
SN streams normally carry a frame of every active module in every timeslice, so
that nothing gets skipped. Note also that only the fully split on-disk layout can
decide this without reading the hits, so for other files the saving is in the loop
body, not in the I/O.

The per-stream shortcuts [`eachL0timeslice`](@ref), [`eachL1timeslice`](@ref),
[`eachL2timeslice`](@ref), [`eachSNtimeslice`](@ref) and [`eachTStimeslice`](@ref)
are also available.

# Example
```
julia> f = ROOTFile(datapath("online", "km3net_online.root"));

julia> for ts ∈ eachtimeslice(f, :L1)
           @show ts.header.frame_index, length(ts.frames)
       end

julia> for ts ∈ eachL1timeslice(f; module_ids=(806451572, 806455814))
           # only timeslices with a frame of one of the two modules
       end

julia> for ts ∈ eachTStimeslice(f; timesorted=true)
           @show ts.header.frame_index  # in time order, not in the order written
       end
```
"""
function eachtimeslice(t::OnlineTree, stream::Symbol; module_ids=(), timesorted=false)
    c = getproperty(t.timeslices, stream)
    TimesliceView(c, Set{Int32}(module_ids), timesorted ? _timeorder(t, stream, c) : nothing)
end
