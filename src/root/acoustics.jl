# Marker type for ROOT customstructs parsing of JACOUSTICS::JDetectorMechanics_t,
# which is a std::map<int, JMechanics> (key=-1 is the wildcard/default entry).
# Returns Dict{Int32, StringMechanicsParameters} with all entries including the wildcard.
struct _JDetectorMechanics_t_Reader end

function UnROOT.readtype(io, ::Type{_JDetectorMechanics_t_Reader}; tkey, original_streamer)
    # io is positioned right after the outer JDetectorMechanics_t preamble.
    #
    # JDetectorMechanics_t inherits map<int,JMechanics> FIRST, TObject SECOND.
    # ROOT serialises the map base class before TObject, so the layout is:
    #
    #   6 bytes    – map preamble (kByteCountMask | bytecount, version)
    #   6 bytes    – unknown (observed: 00 00 0b 5f b7 52)
    #   Int32      – n  (number of map entries)
    #   n × Int32  – all keys (std::map iterates in sorted key order)
    #   n × ( 6-byte JMechanics preamble + Float64 a + Float64 b )
    #   10 bytes   – TObject (version + fUniqueID + fBits, ignored here)
    skip(io, 12)   # skip map preamble (6) + unknown (6)
    n = UnROOT.readtype(io, Int32)
    ks = [UnROOT.readtype(io, Int32) for _ in 1:n]
    result = Dict{Int32, StringMechanicsParameters}()
    for k in ks
        preamble = UnROOT.Preamble(io, Missing)
        a = UnROOT.readtype(io, Float64)
        b = UnROOT.readtype(io, Float64)
        UnROOT.endcheck(io, preamble)
        result[k] = StringMechanicsParameters(a, b)
    end
    result
end

const _ACOUSTICS_CUSTOMSTRUCTS = Dict(
    "JACOUSTICS::JDetectorMechanics_t" => _JDetectorMechanics_t_Reader
)


struct AcousticsFile
    _fobj::UnROOT.ROOTFile
    _transmissions::Union{Nothing, UnROOT.LazyTree}
    _calibration_sets::Union{Nothing, DynamicCalibrationSet}
    _headers::Union{Nothing, UnROOT.LazyTree}

    function AcousticsFile(fname::AbstractString)
        fobj = UnROOT.ROOTFile(fname; customstructs=_ACOUSTICS_CUSTOMSTRUCTS)
        tname = "ACOUSTICS"
        if haskey(fobj, tname)
            bpath = "ACOUSTICS/vector<JACOUSTICS::JTransmission>/vector<JACOUSTICS::JTransmission>"
            transmissions = UnROOT.LazyTree(fobj, tname, [Regex(bpath * ".(run|id|q|w|toe|toa)\$") => s"\1"])
            headers = UnROOT.LazyTree(fobj, tname, [
                Regex("ACOUSTICS/JACOUSTICS::JCounter.(counter)") => s"\1",
                Regex("ACOUSTICS/(detid|overlays|id)") => s"\1",
            ])
        else
            transmissions = nothing
            headers = nothing
        end

        tname = "ACOUSTICS_FIT"
        if haskey(fobj, tname)
            tree = UnROOT.LazyTree(
                fobj,
                "ACOUSTICS_FIT", [
                    Regex("ACOUSTICS_FIT/JACOUSTICS::JHead/UNIXTimeStart") => s"timestart",
                    Regex("ACOUSTICS_FIT/JACOUSTICS::JHead/UNIXTimeStop") => s"timestop",
                    Regex("ACOUSTICS_FIT/JACOUSTICS::JHead/(detid|ndf|npar|nhit|chi2|numberOfIterations|nfit)") => s"\1",
                    Regex("ACOUSTICS_FIT/vector<JACOUSTICS::JFit>/vector<JACOUSTICS::JFit>.((id)|(vs)|(t[xy]2?))") => s"\1"
                ]
            )
            cals = map(tree) do entry
                fits = map(1:length(entry.id)) do idx
                    AcousticsFit(entry.id[idx], entry.tx[idx], entry.ty[idx], entry.tx2[idx], entry.ty2[idx], entry.vs[idx])
                end

                DynamicCalibration(
                    DynamicCalibrationHeader(
                        entry.detid,
                        entry.timestart,
                        entry.timestop,
                        entry.ndf,
                        entry.npar,
                        entry.nhit,
                        entry.chi2,
                        entry.numberOfIterations,
                        entry.nfit,
                    ),
                    fits
                )
            end
            calibration_sets = DynamicCalibrationSet(cals)
        else
            calibration_sets = nothing
        end
        new(fobj, transmissions, calibration_sets, headers)
    end
end


Base.close(f::AcousticsFile) = close(f._fobj)
Base.length(f::AcousticsFile) = isnothing(f._headers) ? 0 : length(f._headers)
Base.firstindex(f::AcousticsFile) = 1
Base.lastindex(f::AcousticsFile) = length(f)
function Base.iterate(f::AcousticsFile, state=1)
    state > length(f) ? nothing : (f[state], state+1)
end
function Base.show(io::IO, f::AcousticsFile)
    print(io, "AcousticsFile ($(length(f)) events)")
end

"""
    detector_mechanics(f::AcousticsFile) -> StringMechanics

Read the `JACOUSTICS::JDetectorMechanics_t` object from a Katoomba acoustics file
and return it as a `StringMechanics`.  The wildcard entry (C++ map key -1) becomes
the `default` field; all other keys populate `stringparams`.
Use `f._fobj["JACOUSTICS::JDetectorMechanics_t"]` for the raw
`Dict{Int32,StringMechanicsParameters}`.
"""
function detector_mechanics(f::AcousticsFile)
    raw = f._fobj["JACOUSTICS::JDetectorMechanics_t"]
    default = get(raw, Int32(-1), StringMechanicsParameters(0.0, 0.0))
    stringparams = Dict{Int, StringMechanicsParameters}(k => v for (k, v) in raw if k != Int32(-1))
    StringMechanics(default, stringparams)
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

Base.eltype(::AcousticsFile) = AcousticsEvent

function Base.getindex(f::AcousticsFile, idx::Integer)
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
Base.getindex(f::AcousticsFile, r::UnitRange) = [f[idx] for idx ∈ r]
Base.getindex(f::AcousticsFile, mask::BitArray) = [f[idx] for (idx, selected) ∈ enumerate(mask) if selected]

function Base.show(io::IO, e::AcousticsEvent)
    print(io, "AcousticsEvent(ID=$(e.id), detector=$(e.det_id), $(e.overlays) overlays, counter=$(e.counter), $(length(e)) transmissions)")
end
