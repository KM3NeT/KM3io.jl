struct ROOTFile
    _fobj::UnROOT.ROOTFile
    online::Union{OnlineTree, Missing}
    offline::Union{OfflineTree, Missing}

    function ROOTFile(filename::AbstractString)
        customstructs = Dict(
            "KM3NETDAQ::JDAQEvent.snapshotHits" => Vector{SnapshotHit},
            "KM3NETDAQ::JDAQEvent.triggeredHits" => Vector{TriggeredHit},
            "KM3NETDAQ::JDAQEvent.KM3NETDAQ::JDAQEventHeader" => EventHeader,
            "KM3NETDAQ::JDAQSummaryslice.KM3NETDAQ::JDAQSummarysliceHeader" => SummarysliceHeader,
            "KM3NETDAQ::JDAQSummaryslice.vector<KM3NETDAQ::JDAQSummaryFrame>" => Vector{SummaryFrame}
        )
        fobj = UnROOT.ROOTFile(filename, customstructs=customstructs)
        tpath_offline = ROOT.TTREE_OFFLINE_EVENT
        offline = tpath_offline ∈ keys(fobj) ? OfflineTree(fobj) : missing
        tpath_online = ROOT.TTREE_ONLINE_EVENT
        online = tpath_online ∈ keys(fobj) ? OnlineTree(fobj) : missing
        new(fobj, online, offline)
    end
end
Base.close(f::ROOTFile) = close(f._fobj)
function Base.show(io::IO, f::ROOTFile)
    s = String[]
    !ismissing(f.online) && push!(s, "$(f.online)")
    !ismissing(f.offline) && push!(s, "$(f.offline)")
    info = join(s, ", ")
    print(io, "ROOTFile{$info}")
end
