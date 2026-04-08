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
[s] with optional sub-second offset `ns` [nanoseconds].

Matches Jpp's `JPolfitFunction1D<20, 1>` interpolation: selects a window of up
to 21 measurements centred roughly on the query time, fits a degree-1 Legendre
polynomial to each quaternion component independently, evaluates at the query
time, then normalises the result. Returns the closest boundary quaternion when
the requested time is outside the recorded range.
"""
function orientation(f::DynamicOrientationFile, module_id::Integer, t::Real, ns::Integer=0)
    fits    = f._lookup[Int32(module_id)]
    N       = length(fits)
    target_t = t + ns * 1e-9

    # Jpp: n = min(N+1, size) = min(21, N)
    n = min(21, N)

    # lower_bound: first 1-based index where fit.t >= target_t
    idx = searchsortedfirst(fits, target_t; lt = (fit, x) -> fit.t + fit.ns * 1e-9 < x)

    # outside range: return nearest boundary (Jpp throws; we fall back gracefully)
    idx == 1 && fits[1].t + fits[1].ns * 1e-9 > target_t && return fits[1].q
    idx > N  && return fits[N].q

    # Replicate Jpp's window-centering logic (0-based j = idx - 1):
    #   step 2: advance j by n÷2 (capped at N, the end sentinel)
    #   step 3: go back n steps from there (capped at 0)
    j = idx - 1                               # 0-based lower_bound position
    step2 = min(j + n ÷ 2, N)                # 0-based, may equal N (end sentinel)
    p0    = max(step2 - n, 0)                 # 0-based window start
    p     = p0 + 1                            # 1-based
    wend  = min(p + n - 1, N)
    window = fits[p:wend]
    nw    = length(window)

    # x-axis: time elapsed from window start
    t0 = window[1].t + window[1].ns * 1e-9
    xs = [f.t + f.ns * 1e-9 - t0 for f in window]
    xq = target_t - t0
    xm = xs[end]

    # Degenerate window (all at same time): return closest measurement
    xm == 0.0 && return window[1].q

    # Legendre normalised x ∈ [-1, 1]: z_i = 2*x_i/x_max - 1
    zs = [2*x/xm - 1 for x in xs]
    zq = 2*xq/xm - 1

    # Degree-1 Legendre series fit (JLegendre<T, 1> algorithm):
    #   c₀ = Σ P₀(zᵢ)⋅yᵢ / Σ P₀(zᵢ)²  =  mean(y)
    #   c₁ = Σ P₁(zᵢ)⋅(yᵢ − c₀) / Σ P₁(zᵢ)²  (P₁(z) = z)
    #   ŷ(x) = c₀⋅P₀(zq) + c₁⋅P₁(zq) = c₀ + c₁⋅zq
    sum_z2 = sum(z^2 for z in zs)
    function legfit(vals)
        c0 = sum(vals) / nw
        c1 = iszero(sum_z2) ? zero(c0) :
             sum(zs[i] * (vals[i] - c0) for i in 1:nw) / sum_z2
        c0 + c1 * zq
    end

    q = Quaternion(legfit([f.q.q0 for f in window]),
                   legfit([f.q.qx for f in window]),
                   legfit([f.q.qy for f in window]),
                   legfit([f.q.qz for f in window]))
    normalize(q)
end


# Dynamic position calibration

# Standard Legendre polynomial P_n(x).
function _legendre_poly(n::Int, x::Float64)
    n == 0 && return 1.0
    n == 1 && return x
    p0, p1 = 1.0, x
    for i in 2:n
        p2 = ((2i - 1) * x * p1 - (i - 1) * p0) / i
        p0, p1 = p1, p2
    end
    p1
end


# Legendre polynomial interpolation matching Jpp's JPolfitFunction<N_POINTS, DEGREE>.
# ts  : sorted abscissa values  (length ≥ 1)
# ys  : corresponding scalar ordinates
# t   : query abscissa
# n_points : N parameter (window size = min(N+1, length(ts)))
# degree   : polynomial degree M
function _polfit_eval(ts::Vector{Float64}, ys::Vector{Float64},
                      t::Float64, n_points::Int, degree::Int)
    N  = length(ts)
    n  = min(n_points + 1, N)

    idx = searchsortedfirst(ts, t)
    idx == 1 && ts[1] > t && return ys[1]
    idx > N  && return ys[N]

    # Window centering: replicate JPolfitFunction::evaluate
    j     = idx - 1
    step2 = min(j + n ÷ 2, N)
    p0    = max(step2 - n, 0)
    p     = p0 + 1
    wend  = min(p + n - 1, N)

    ws_t = ts[p:wend]
    ws_y = ys[p:wend]
    nw   = length(ws_t)

    t0 = ws_t[1]
    xm = ws_t[end] - t0
    xq = t - t0
    xm == 0.0 && return ws_y[1]

    # JLegendre normalised coordinates: z = 2*(x - xmin)/(xmax - xmin) - 1
    # Here xmin = 0, xmax = xm  (distances from window start).
    zs = [2.0*(wt - t0)/xm - 1.0 for wt in ws_t]
    zq = 2.0*xq/xm - 1.0

    # Sequential Legendre series fit (JLegendre<T,M>::set algorithm):
    #   for each degree n: c_n = Σ P_n(z_i)*(y_i - Σ_{k<n} c_k P_k(z_i)) / Σ P_n(z_i)²
    coeffs  = zeros(degree + 1)
    current = zeros(nw)
    for deg in 0:degree
        V = 0.0
        W = 0.0
        for i in 1:nw
            w  = _legendre_poly(deg, zs[i])
            V += w * (ws_y[i] - current[i])
            W += w * w
        end
        c = iszero(W) ? 0.0 : V / W
        coeffs[deg + 1] = c
        for i in 1:nw
            current[i] += c * _legendre_poly(deg, zs[i])
        end
    end

    result = 0.0
    for deg in 0:degree
        result += coeffs[deg + 1] * _legendre_poly(deg, zq)
    end
    result
end


# Interpolate all five AcousticsFit fields at time t using JPolfitFunction<7,2>.
function _interpolate_acoustics_fit(ts::Vector{Float64}, fits::Vector{AcousticsFit}, t::Float64)
    AcousticsFit(
        fits[1].id,
        _polfit_eval(ts, [f.tx  for f in fits], t, 7, 2),
        _polfit_eval(ts, [f.ty  for f in fits], t, 7, 2),
        _polfit_eval(ts, [f.tx2 for f in fits], t, 7, 2),
        _polfit_eval(ts, [f.ty2 for f in fits], t, 7, 2),
        _polfit_eval(ts, [f.vs  for f in fits], t, 7, 2),
    )
end


# Arc length along the tilted string from z=0 to z  (Jpp: JString::getLength).
function _string_arc_length(fit::AcousticsFit, mech::StringMechanicsParameters, z::Float64)
    T2 = fit.tx^2 + fit.ty^2
    x  = 1.0 - mech.a * z
    sqrt(1.0 + T2) * z  +  T2 * mech.b * log(x)  +
        0.5 * T2 * mech.a * mech.b^2 * (1.0/x - 1.0)
end


# Solve for height z such that arc_length(z) = h1  (Jpp: JString::getHeight).
function _string_solve_z(fit::AcousticsFit, mech::StringMechanicsParameters, h1::Float64;
                          precision::Float64 = 1e-4, max_iter::Int = 10)
    T2 = fit.tx^2 + fit.ty^2
    z  = h1
    for _ in 1:max_iter
        ls = _string_arc_length(fit, mech, z) - h1
        abs(ls) <= precision && break
        vs_loc = 1.0 - mech.a * mech.b / (1.0 - mech.a * z)
        z -= ls / (1.0 + 0.5 * T2 * vs_loc^2)
    end
    z
end


# (dx, dy, dz) from anchor to piezo at the given pre-stretch height.
# Replicates JACOUSTICS::JGEOMETRY::JString::getPosition(params, mechanics, height).
function _string_displacement(fit::AcousticsFit, mech::StringMechanicsParameters, height::Float64)
    h1 = height * (1.0 + fit.vs)
    z1 = h1 + mech.b * log(1.0 - mech.a * h1)
    dx = fit.tx  * z1 + fit.tx2 * h1^2
    dy = fit.ty  * z1 + fit.ty2 * h1^2
    dz = _string_solve_z(fit, mech, h1)
    (dx, dy, dz)
end


"""
    calibrate_position(det::Detector, f::DynamicPositionFile, t::Real) -> Detector

Apply dynamic position calibration to the detector at UNIX time `t` [s], using
acoustic string fit data from `f`.

Matches Jpp's `JDynamics::JPosition::update`: for each string with coverage at `t`,
the per-string acoustic fit parameters (`tx`, `ty`, `tx2`, `ty2`, `vs`) are interpolated
using a 7-point degree-2 Legendre polynomial (`JPolfitFunction1D<7,2>`), and the
resulting string shape model is used to update each module's position.

Modules on strings without calibration data, or whose string's time range does not
cover `t`, are left at their static positions.  Base modules (floor 0) are never moved.
"""
function calibrate_position(det::Detector, f::DynamicPositionFile, t::Real)
    isnothing(f._calibration_sets) && return det

    sm = detector_mechanics(f)

    # Build per-string sorted calibration: string_id => (times, fits)
    str_times = Dict{Int32, Vector{Float64}}()
    str_fits  = Dict{Int32, Vector{AcousticsFit}}()
    for cal in f._calibration_sets.calibrations
        t_mid = 0.5 * (cal.header.timestart + cal.header.timestop)
        for fit in cal.fits
            sid = Int32(fit.id)
            push!(get!(Vector{Float64},      str_times, sid), t_mid)
            push!(get!(Vector{AcousticsFit}, str_fits,  sid), fit)
        end
    end
    for sid in keys(str_times)
        ord           = sortperm(str_times[sid])
        str_times[sid] = str_times[sid][ord]
        str_fits[sid]  = str_fits[sid][ord]
    end

    # Anchor positions: position of floor-0 module for each string.
    str_anchor = Dict{Int32, Position{Float64}}()
    for mod in values(det.modules)
        isbasemodule(mod) && (str_anchor[mod.location.string] = mod.pos)
    end

    piezo_dz = -0.20   # piezo is 0.20 m below the module centre in z

    new_modules = Dict{Int32, DetectorModule}()
    for (mid, mod) in det.modules
        sid = mod.location.string

        if isbasemodule(mod) ||
           !haskey(str_times, sid) ||
           !haskey(str_anchor, sid)
            new_modules[mid] = mod
            continue
        end

        ts = str_times[sid]
        if t < ts[1] || t > ts[end]
            new_modules[mid] = mod
            continue
        end

        anchor = str_anchor[sid]
        mech   = sm[Int(sid)]

        # Euclidean distance from anchor to piezo (0.20 m below module centre).
        piezo_z = mod.pos.z + piezo_dz
        height  = sqrt((mod.pos.x - anchor.x)^2 + (mod.pos.y - anchor.y)^2 + (piezo_z - anchor.z)^2)

        # Static 2D floor offset relative to string anchor.
        floor_dx = mod.pos.x - anchor.x
        floor_dy = mod.pos.y - anchor.y

        fit_interp = _interpolate_acoustics_fit(ts, str_fits[sid], Float64(t))
        (dx, dy, dz) = _string_displacement(fit_interp, mech, height)

        new_pos = Position{Float64}(
            anchor.x + dx + floor_dx,
            anchor.y + dy + floor_dy,
            anchor.z + dz - piezo_dz,   # +0.20: piezo position → module centre
        )

        # Translate PMT positions (absolute world-frame) by the same delta.
        Δx = new_pos.x - mod.pos.x
        Δy = new_pos.y - mod.pos.y
        Δz = new_pos.z - mod.pos.z
        new_pmts = [PMT(p.id, Position{Float64}(p.pos.x + Δx, p.pos.y + Δy, p.pos.z + Δz),
                        p.dir, p.t₀, p.status) for p in mod.pmts]

        new_modules[mid] = DetectorModule(mod.id, new_pos, mod.location, mod.n_pmts,
                                          new_pmts, mod.q, mod.status, mod.t₀)
    end

    # Rebuild auxiliary lookup dicts.
    new_locations = Dict{Tuple{Int, Int}, Int32}()
    new_pmt_id_map = Dict{Int, Int32}()
    for m in values(new_modules)
        new_locations[(m.location.string, m.location.floor)] = m.id
        for pmt in m.pmts
            new_pmt_id_map[pmt.id] = m.id
        end
    end

    Detector(det.version, det.id, det.validity, det.pos, det.lonlat, det.utm_ref_grid,
             det.n_modules, new_modules, new_locations, det.strings, det.comments, new_pmt_id_map)
end
