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


struct DynamicPositionFile
    _fobj::UnROOT.ROOTFile
    _transmissions::Union{Nothing, UnROOT.LazyTree}
    _calibration_sets::Union{Nothing, DynamicPositionSet}
    _headers::Union{Nothing, UnROOT.LazyTree}

    function DynamicPositionFile(fname::AbstractString)
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

                DynamicPosition(
                    DynamicPositionHeader(
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
            calibration_sets = DynamicPositionSet(cals)
        else
            calibration_sets = nothing
        end
        new(fobj, transmissions, calibration_sets, headers)
    end
end


Base.close(f::DynamicPositionFile) = close(f._fobj)
Base.length(f::DynamicPositionFile) = isnothing(f._headers) ? 0 : length(f._headers)
Base.firstindex(f::DynamicPositionFile) = 1
Base.lastindex(f::DynamicPositionFile) = length(f)
function Base.iterate(f::DynamicPositionFile, state=1)
    state > length(f) ? nothing : (f[state], state+1)
end
function Base.show(io::IO, f::DynamicPositionFile)
    print(io, "DynamicPositionFile ($(length(f)) events)")
end

"""
    detector_mechanics(f::DynamicPositionFile) -> StringMechanics

Read the `JACOUSTICS::JDetectorMechanics_t` object from a Katoomba acoustics file
and return it as a `StringMechanics`.  The wildcard entry (C++ map key -1) becomes
the `default` field; all other keys populate `stringparams`.
Use `f._fobj["JACOUSTICS::JDetectorMechanics_t"]` for the raw
`Dict{Int32,StringMechanicsParameters}`.
"""
function detector_mechanics(f::DynamicPositionFile)
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

Base.eltype(::DynamicPositionFile) = AcousticsEvent

function Base.getindex(f::DynamicPositionFile, idx::Integer)
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
Base.getindex(f::DynamicPositionFile, r::UnitRange) = [f[idx] for idx ∈ r]
Base.getindex(f::DynamicPositionFile, mask::BitArray) = [f[idx] for (idx, selected) ∈ enumerate(mask) if selected]

function Base.show(io::IO, e::AcousticsEvent)
    print(io, "AcousticsEvent(ID=$(e.id), detector=$(e.det_id), $(e.overlays) overlays, counter=$(e.counter), $(length(e)) transmissions)")
end


function _orientation_fit(e)
    OrientationFit(
        e.id, e.t, e.ns,
        Quaternion(
            getproperty(e, Symbol("JCOMPASS::JQuaternion_a")),
            getproperty(e, Symbol("JCOMPASS::JQuaternion_b")),
            getproperty(e, Symbol("JCOMPASS::JQuaternion_c")),
            getproperty(e, Symbol("JCOMPASS::JQuaternion_d"))
        ),
        e.policy
    )
end

"""
    DynamicOrientationFile(filename)

Reader for dynamic orientation ROOT files produced by Jpp. Builds a per-module
lookup of `OrientationFit` entries sorted by time so that
[`orientation`](@ref) can interpolate quaternions at arbitrary timestamps.
"""
struct DynamicOrientationFile
    _fobj::UnROOT.ROOTFile
    _fits::UnROOT.LazyTree
    _lookup::Dict{Int32, Vector{OrientationFit}}

    function DynamicOrientationFile(fname::AbstractString)
        fobj = UnROOT.ROOTFile(fname)
        fits = UnROOT.LazyTree(fobj, "ORIENTATION")
        lookup = Dict{Int32, Vector{OrientationFit}}()
        for row in fits
            fit = _orientation_fit(row)
            push!(get!(Vector{OrientationFit}, lookup, fit.id), fit)
        end
        for v in values(lookup)
            sort!(v, by = f -> f.t + f.ns * 1e-9)
        end
        new(fobj, fits, lookup)
    end
end

Base.close(f::DynamicOrientationFile) = close(f._fobj)
Base.length(f::DynamicOrientationFile) = length(f._fits)
Base.firstindex(f::DynamicOrientationFile) = 1
Base.lastindex(f::DynamicOrientationFile) = length(f)
Base.eltype(::DynamicOrientationFile) = OrientationFit

function Base.iterate(f::DynamicOrientationFile, state=1)
    state > length(f) && return nothing
    (_orientation_fit(f._fits[state]), state + 1)
end

function Base.getindex(f::DynamicOrientationFile, idx::Integer)
    _orientation_fit(f._fits[idx])
end
Base.getindex(f::DynamicOrientationFile, r::UnitRange) = [f[idx] for idx ∈ r]

function Base.show(io::IO, f::DynamicOrientationFile)
    n = length(f._lookup)
    total = length(f)
    if n > 0
        t_min = minimum(first(v).t for v in values(f._lookup))
        t_max = maximum(last(v).t  for v in values(f._lookup))
        print(io, "DynamicOrientationFile ($total measurements, $n modules, $(unix2datetime(t_min)) - $(unix2datetime(t_max)))")
    else
        print(io, "DynamicOrientationFile (empty)")
    end
end

"""
    orientation(f::DynamicOrientationFile, module_id, t, ns=0) -> Quaternion

Return the interpolated orientation quaternion for `module_id` at UNIX time `t`
[s] with optional sub-second offset `ns` [nanoseconds]. Uses spherical linear
interpolation (slerp) between the two nearest measurements. Returns the closest
boundary quaternion when the requested time is outside the recorded range.
"""
function orientation(f::DynamicOrientationFile, module_id::Integer, t::Real, ns::Integer=0)
    fits = f._lookup[Int32(module_id)]
    target_t = t + ns * 1e-9

    idx = searchsortedfirst(fits, target_t; lt = (fit, x) -> fit.t + fit.ns * 1e-9 < x)

    # outside range: return nearest boundary
    (idx == 1 || idx > length(fits)) && return fits[clamp(idx, 1, length(fits))].q

    before = fits[idx - 1]
    after  = fits[idx]
    t1 = before.t + before.ns * 1e-9
    t2 = after.t  + after.ns  * 1e-9
    Δt = t2 - t1
    Δt == 0.0 && return before.q
    slerp(before.q, after.q, (target_t - t1) / Δt)
end
