struct EvtHit
end

struct MCHit
end

struct Trk
end

struct MCTrk
end

struct Evt
    id::Int64  # offline event identifier
    det_id::Int64
    mc_id::Int64

    run_id::Int64
    mc_run_id::Int64

    frame_index::Int64
    trigger_mask::UInt64
    trigger_counter::UInt64
    overlays::UInt64
    t::UTCTime

    header_uuid::UUID

    hits::Vector{EvtHit}
    trks::Vector{Trk}

    # MC related fields
    w::Vector{Float64}
    w2list::Vector{Float64}  # (see e.g. <a href="https://simulation.pages.km3net.de/taglist/taglist.pdf">Tag list</a> or km3net-dataformat/definitions)
    w3list::Vector{Float64}  # atmospheric flux information

    mc_event_time::UTCTime
    mc_t::Float64
    mc_hits::Vector{MCHit}
    mc_trks::Vector{MCTrk}

    comment::AbstractString
    index::Int64
    flags::Int64
end

struct EvtContainer

end

struct OfflineFile
    _fobj::UnROOT.ROOTFile

    function OfflineFile(filename::AbstractString)
        fobj = UnROOT.ROOTFile(filename)

        new(fobj)
    end
end

Base.close(c::OfflineFile) = close(f._fobj)



function Base.getindex(f::OfflineFile, idx::Integer)
    bpath = ROOT.TTREE_OFFLINE_EVENT * "/" * ROOT.TBRANCH_OFFLINE_EVENT
    LazyBranch(f._fobj, bpath * "/trks/trks.id")[idx]
end
