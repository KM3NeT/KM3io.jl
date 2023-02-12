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
    T(detector_id, run, frame_index, UTC_seconds, UTC_16nanosecondcycles, trigger_counter, trigger_mask, overlays)
end
function UnROOT.interped_data(rawdata, rawoffsets, ::Type{EventHeader}, ::Type{T}) where {T <: UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, EventHeader, jagged=false)
end

function Base.show(io::IO, e::DAQEvent)
    print(io, "$(typeof(e)) with $(length(e.snapshot_hits)) snapshot and $(length(e.triggered_hits)) triggered hits")
end

struct EventContainer
    headers
    snapshot_hits
    triggered_hits
end
function Base.show(io::IO, e::EventContainer)
    print(io, "$(typeof(e)) with $(length(e.headers)) events")
end

struct OnlineFile
    _fobj::UnROOT.ROOTFile
    events::EventContainer

    function OnlineFile(filename::AbstractString)
        customstructs = Dict(
            "KM3NETDAQ::JDAQEvent.snapshotHits" => Vector{SnapshotHit},
            "KM3NETDAQ::JDAQEvent.triggeredHits" => Vector{TriggeredHit},
            "KM3NETDAQ::JDAQEvent.KM3NETDAQ::JDAQEventHeader" => EventHeader
        )
        fobj = UnROOT.ROOTFile(filename, customstructs=customstructs)

        new(fobj,
            EventContainer(
                LazyBranch(fobj, "KM3NET_EVENT/KM3NET_EVENT/KM3NETDAQ::JDAQEventHeader"),
                LazyBranch(fobj, "KM3NET_EVENT/KM3NET_EVENT/snapshotHits"),
                LazyBranch(fobj, "KM3NET_EVENT/KM3NET_EVENT/triggeredHits"))
            )
    end
end
Base.close(c::OnlineFile) = close(f._fobj)
Base.show(io::IO, f::OnlineFile) = print(io, "$(typeof(f)) with $(length(f.events)) events")

Base.getindex(c::EventContainer, idx::Integer) = DAQEvent(c.headers[idx], c.snapshot_hits[idx], c.triggered_hits[idx])
Base.getindex(c::EventContainer, r::UnitRange) = [c[idx] for idx ∈ r]
Base.getindex(c::EventContainer, mask::BitArray) = [c[idx] for (idx, selected) ∈ enumerate(mask) if selected]
Base.length(c::EventContainer) = length(c.headers)
Base.eltype(c::EventContainer) = DAQEvent
function Base.iterate(c::EventContainer, state=1)
    state > length(c) ? nothing : (DAQEvent(c.headers[state], c.snapshot_hits[state], c.triggered_hits[state]), state+1)
end

function read_headers(f::OnlineFile)
    data, offsets = UnROOT.array(f.fobj, "KM3NET_EVENT/KM3NET_EVENT/KM3NETDAQ::JDAQEventHeader"; raw=true)
    UnROOT.splitup(data, offsets, EventHeader; jagged=false)
end

function read_snapshot_hits(f::OnlineFile)
    data, offsets = UnROOT.array(f.fobj, "KM3NET_EVENT/KM3NET_EVENT/snapshotHits"; raw=true)
    UnROOT.splitup(data, offsets, SnapshotHit, skipbytes=10)
end

function read_triggered_hits(f::OnlineFile)
    data, offsets = UnROOT.array(f.fobj, "KM3NET_EVENT/KM3NET_EVENT/triggeredHits"; raw=true)
    UnROOT.splitup(data, offsets, TriggeredHit, skipbytes=10)
end
