struct KM3NETDAQSnapshotHit <: UnROOT.CustomROOTStruct
    dom_id::Int32
    channel_id::UInt8
    t::Int32
    tot::UInt8
end
function UnROOT.readtype(io, T::Type{KM3NETDAQSnapshotHit})
    T(UnROOT.readtype(io, Int32), read(io, UInt8), read(io, Int32), read(io, UInt8))
end
function UnROOT.interped_data(rawdata, rawoffsets, ::Type{Vector{KM3NETDAQSnapshotHit}}, ::Type{J}) where {T, J <: UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, KM3NETDAQSnapshotHit, skipbytes=10)
end

struct KM3NETDAQTriggeredHit <: UnROOT.CustomROOTStruct
    dom_id::Int32
    channel_id::UInt8
    t::Int32
    tot::UInt8
    trigger_mask::UInt64
end
UnROOT.packedsizeof(::Type{KM3NETDAQTriggeredHit}) = 24  # incl. cnt and vers

function UnROOT.readtype(io, T::Type{KM3NETDAQTriggeredHit})
    dom_id = UnROOT.readtype(io, Int32)
    channel_id = read(io, UInt8)
    tdc = read(io, Int32)
    tot = read(io, UInt8)
    cnt = read(io, UInt32)
    vers = read(io, UInt16)
    trigger_mask = UnROOT.readtype(io, UInt64)
    T(dom_id, channel_id, tdc, tot, trigger_mask)
end

function UnROOT.interped_data(rawdata, rawoffsets, ::Type{Vector{KM3NETDAQTriggeredHit}}, ::Type{J}) where {T, J <: UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, KM3NETDAQTriggeredHit, skipbytes=10)
end

struct KM3NETDAQEventHeader
    detector_id::Int32
    run::Int32
    frame_index::Int32
    UTC_seconds::UInt32
    UTC_16nanosecondcycles::UInt32
    trigger_counter::UInt64
    trigger_mask::UInt64
    overlays::UInt32
end
packedsizeof(::Type{KM3NETDAQEventHeader}) = 76

function UnROOT.readtype(io::IO, T::Type{KM3NETDAQEventHeader})
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
function UnROOT.interped_data(rawdata, rawoffsets, ::Type{KM3NETDAQEventHeader}, ::Type{J}) where {T, J <: UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, KM3NETDAQEventHeader, jagged=false)
end

struct OnlineEvent
    header::KM3NETDAQEventHeader
    snapshot_hits::Vector{KM3NETDAQSnapshotHit}
    triggered_hits::Vector{KM3NETDAQTriggeredHit}
end

struct OnlineFile
    fobj::UnROOT.ROOTFile
    headers::Vector{KM3NETDAQEventHeader}
    snapshot_hits
    triggered_hits

    function OnlineFile(filename::AbstractString)
        customstructs = Dict(
            "KM3NETDAQ::JDAQEvent.snapshotHits" => Vector{KM3NETDAQSnapshotHit},
            "KM3NETDAQ::JDAQEvent.triggeredHits" => Vector{KM3NETDAQTriggeredHit},
            "KM3NETDAQ::JDAQEvent.KM3NETDAQ::JDAQEventHeader" => KM3NETDAQEventHeader
        )
        fobj = UnROOT.ROOTFile(filename, customstructs=customstructs)

        new(fobj,
            fobj["KM3NET_EVENT/KM3NET_EVENT/KM3NETDAQ::JDAQEventHeader"],
            fobj["KM3NET_EVENT/KM3NET_EVENT/snapshotHits"],
            fobj["KM3NET_EVENT/KM3NET_EVENT/triggeredHits"])
    end
end
Base.getindex(f::OnlineFile, idx::Integer) = OnlineEvent(
    f.headers[idx], f.snapshot_hits[idx], f.triggered_hits[idx]
)
Base.length(f::OnlineFile) = length(f.headers)

Base.close(f::OnlineFile) = close(f.fobj)

function read_headers(f::OnlineFile)
    data, offsets = UnROOT.array(f.fobj, "KM3NET_EVENT/KM3NET_EVENT/KM3NETDAQ::JDAQEventHeader"; raw=true)
    UnROOT.splitup(data, offsets, KM3NETDAQEventHeader; jagged=false)
end

function read_snapshot_hits(f::OnlineFile)
    data, offsets = UnROOT.array(f.fobj, "KM3NET_EVENT/KM3NET_EVENT/snapshotHits"; raw=true)
    UnROOT.splitup(data, offsets, KM3NETDAQSnapshotHit, skipbytes=10)
end

function read_triggered_hits(f::OnlineFile)
    data, offsets = UnROOT.array(f.fobj, "KM3NET_EVENT/KM3NET_EVENT/triggeredHits"; raw=true)
    UnROOT.splitup(data, offsets, KM3NETDAQTriggeredHit, skipbytes=10)
end
