struct AcousticsEventFile
    _fobj::UnROOT.ROOTFile
    _transmissions
    _headers

    function AcousticsEventFile(fname::AbstractString)
        fobj = UnROOT.ROOTFile(fname)
        tname = "ACOUSTICS"
        bpath = "ACOUSTICS/vector<JACOUSTICS::JTransmission>/vector<JACOUSTICS::JTransmission>"
        transmissions = UnROOT.LazyTree(fobj, tname, [Regex(bpath * ".(run|id|q|w|toe|toa)\$") => s"\1"])
        headers = UnROOT.LazyTree(fobj, tname, [
            Regex("ACOUSTICS/JACOUSTICS::JCounter.(counter)") => s"\1",
            Regex("ACOUSTICS/(detid|overlays|id)") => s"\1",
        ])
        new(fobj, transmissions, headers)
    end
end


Base.close(f::AcousticsEventFile) = close(f._fobj)
Base.length(f::AcousticsEventFile) = length(f._headers)
Base.firstindex(f::AcousticsEventFile) = 1
Base.lastindex(f::AcousticsEventFile) = length(f)
function Base.iterate(f::AcousticsEventFile, state=1)
    state > length(f) ? nothing : (f[state], state+1)
end
function Base.show(io::IO, f::AcousticsEventFile)
    print(io, "AcousticsEventFile ($(length(f)) events)")
end

struct Transmission
    run::Int32
    id::Int32
    q::Float64
    w::Float64
    toe::Float64
    toa::Float64
end
function Base.show(io::IO, t::Transmission)
    @printf(io, "Transmission (run=%d, id=%d, q=%.1f, w=%.1f, Δt=%.1fms, TOA=%s)", t.run, t.id, t.q, t.w, (t.toa - t.toe)*1e3, unix2datetime(t.toa))
end

struct AcousticsEvent
    id::Int32
    det_id::Int32
    overlays::Int32
    counter::Int32
    transmissions::Vector{Transmission}
end
Base.length(e::AcousticsEvent) = length(e.transmissions)

Base.eltype(::AcousticsEventFile) = AcousticsEvent

function Base.getindex(f::AcousticsEventFile, idx::Integer)
    tr = f._transmissions[idx]
    h = f._headers[idx]
    n = length(tr.id)  # arbitrary field for length determination
    transmissions = Vector{Transmission}(undef, n)
    transmissions = sizehint!(Vector{Transmission}(), n)
    for i in 1:n
        push!(transmissions, Transmission(tr.run[i], tr.id[i], tr.q[i], tr.w[i], tr.toe[i], tr.toa[i]))
    end
    return AcousticsEvent(h.id, h.detid, h.overlays, h.counter, transmissions)
end
Base.getindex(f::AcousticsEventFile, r::UnitRange) = [f[idx] for idx ∈ r]
Base.getindex(f::AcousticsEventFile, mask::BitArray) = [f[idx] for (idx, selected) ∈ enumerate(mask) if selected]

function Base.show(io::IO, e::AcousticsEvent)
    print(io, "AcousticsEvent(ID=$(e.id), detector=$(e.detid), $(e.overlays) overlays, counter=$(e.counter), $(length(e)) transmissions)")
end
