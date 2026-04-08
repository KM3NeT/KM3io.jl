"""
    reference_rotation(mod::DetectorModule) -> Quaternion

Compute the rotation quaternion `Q0` that maps the canonical (factory reference)
PMT directions ([`CANONICAL_PMT_DIRECTIONS`](@ref)) to the current static PMT
directions stored in `mod`.

This replicates Jpp's `getRotation(canonical_module, static_module)` using a
modified Gram-Schmidt process on all 31 PMT direction pairs, keeping only the
first three orthonormal basis vectors to build the rotation matrix, which is
then converted to a quaternion.

PMTs are paired by `pmt.id` (1–31), which corresponds to channel (TDC) order
for Jpp-generated DETX/DATX files.
"""
function reference_rotation(mod::DetectorModule)
    N = length(mod.pmts)
    # Mutable copies: canonical and static direction vectors, paired by channel index.
    # mod.pmts is in channel order (0..N-1) for Jpp-generated DETX/DATX files, and
    # CANONICAL_PMT_DIRECTIONS is stored in the same channel order.
    # Pre-normalise canonical directions to unit vectors, matching Jpp's JVersor3D which
    # produces exactly unit vectors. The stored constants are rounded and may deviate
    # slightly from 1.0, which would otherwise cause out_vecs to be scaled non-uniformly
    # during Gram-Schmidt.
    in_vecs  = map(1:N) do i
        d = CANONICAL_PMT_DIRECTIONS[i]
        n = sqrt(d.x^2 + d.y^2 + d.z^2)
        [d.x/n, d.y/n, d.z/n]
    end
    out_vecs = [[p.dir.x, p.dir.y, p.dir.z] for p in mod.pmts]

    # Gram-Schmidt: orthonormalise the first 3 directions (Jpp convention)
    for i in 1:3
        # pick the remaining vector with the largest squared norm
        pos = i
        max_len2 = sum(x -> x^2, in_vecs[i])
        for j in i+1:N
            len2 = sum(x -> x^2, in_vecs[j])
            if len2 > max_len2
                max_len2 = len2
                pos = j
            end
        end

        u = sqrt(sum(x -> x^2, in_vecs[pos]))
        in_vecs[pos]  ./= u
        out_vecs[pos] ./= u

        if pos != i
            in_vecs[i],  in_vecs[pos]  = in_vecs[pos],  in_vecs[i]
            out_vecs[i], out_vecs[pos] = out_vecs[pos], out_vecs[i]
        end

        # remove component along the new basis vector from all remaining vectors
        for j in i+1:N
            d = sum(in_vecs[i] .* in_vecs[j])
            in_vecs[j]  .-= d .* in_vecs[i]
            out_vecs[j] .-= d .* out_vecs[i]
        end
    end

    # Build rotation matrix R = Σ_k out[k] ⊗ in[k]ᵀ  (R*in[k] = out[k])
    R = zeros(3, 3)
    for k in 1:3, a in 1:3, b in 1:3
        R[a, b] += out_vecs[k][a] * in_vecs[k][b]
    end

    rotation_matrix_to_quaternion(R)
end


"""
    calibrate_orientation(mod::DetectorModule, Q_dynamic::Quaternion) -> DetectorModule

Apply dynamic orientation calibration to a module following Jpp's `JDynamics`
algorithm:

1. Compute `Q0 = reference_rotation(mod)` — the rotation from the canonical
   (factory) frame to the current static geometry, derived from the actual PMT
   direction vectors via Gram-Schmidt (matching Jpp's `getRotation`).
2. Compute `Q1 = mod.q ⊗ Q_dynamic` — the combined static + compass rotation.
3. Apply the delta `Δ = Q1 ⊗ conj(Q0)` to all PMT directions as a sandwich
   product `Δ ⊗ d_pure ⊗ conj(Δ)`.

`Q_dynamic` is the interpolated compass reading at the time of interest, e.g.
from [`orientation`](@ref).  Returns a new `DetectorModule` with updated PMT
directions and `q` field set to `Q1`.
"""
function calibrate_orientation(mod::DetectorModule, Q_dynamic::Quaternion)
    Q0 = normalize(reference_rotation(mod))   # from PMT directions (Jpp: getRotation)
    Q1 = normalize(mod.q ⊗ Q_dynamic)         # Q_static * Q_dynamic
    Δ  = Q1 ⊗ conj(Q0)
    rotated_pmts = map(mod.pmts) do p
        r_dir = Δ ⊗ Quaternion(zero(Float64), p.dir.x, p.dir.y, p.dir.z) ⊗ conj(Δ)
        # Rotate PMT position around the module centre (positions are absolute world-frame)
        rel_x = p.pos.x - mod.pos.x
        rel_y = p.pos.y - mod.pos.y
        rel_z = p.pos.z - mod.pos.z
        r_pos = Δ ⊗ Quaternion(zero(Float64), rel_x, rel_y, rel_z) ⊗ conj(Δ)
        new_pos = Position{Float64}(mod.pos.x + r_pos.qx, mod.pos.y + r_pos.qy, mod.pos.z + r_pos.qz)
        PMT(p.id, new_pos, Direction(r_dir.qx, r_dir.qy, r_dir.qz), p.t₀, p.status)
    end
    DetectorModule(mod.id, mod.pos, mod.location, mod.n_pmts, rotated_pmts, Q1, mod.status, mod.t₀)
end

"""

Apply full geometry and time calibration to given hits. This way of calibration
should be used wisely since it creates a very bloaded [`XCalibratedHit`](@ref)
object, which might not be necessary. Often, we only need time the calibration
to be applied.

"""
function calibrate(det::Detector, hits)
    calibrated_hits = Vector{XCalibratedHit}()
    has_trigger_mask = :trigger_mask ∈ fieldnames(eltype(hits))
    for hit in hits
        dom_id = hit.dom_id
        channel_id = hit.channel_id
        tot = hit.tot
        pos = det[dom_id][channel_id].pos
        dir = det[dom_id][channel_id].dir
        t0 = det[dom_id][channel_id].t₀
        t = hit.t + t0
        string = det[dom_id].location.string
        floor = det[dom_id].location.floor
        trigger_mask = has_trigger_mask ? hit.trigger_mask : 0
        c_hit = XCalibratedHit(
            dom_id, channel_id, t, tot, trigger_mask,
            pos, dir, t0,
            string, floor
        )
        push!(calibrated_hits, c_hit)
    end
    calibrated_hits
end

Base.time(det::Detector, hit; correct_slew=true) = time(hit; correct_slew=correct_slew) + getpmt(det, hit).t₀

"""

Calibrate the time of a given array of snapshot hits.

"""
function calibratetime(det::Detector, hits::Vector{T}) where T<:SnapshotHit
    out = sizehint!(Vector{CalibratedSnapshotHit}(), length(hits))
    for h in hits
        push!(out, CalibratedSnapshotHit(h.dom_id, h.channel_id, h.t + getpmt(det, h).t₀, h.tot))
    end
    out
end

"""

Calibrate the time of a given array of triggered hits.

"""
function calibratetime(det::Detector, hits::Vector{T}) where T<:TriggeredHit
    out = sizehint!(Vector{CalibratedTriggeredHit}(), length(hits))
    for h in hits
        push!(out, CalibratedSnapshotHit(h.dom_id, h.channel_id, h.t + getpmt(det, h).t₀, h.tot, h.trigger_mask))
    end
    out
end

"""
Combine snapshot and triggered hits to a single hits-vector.

This should be used to transfer the trigger information to the
snapshot hits from a DAQEvent. The triggered hits are a subset
of the snapshot hits.

"""
function combine(snapshot_hits::Vector{KM3io.SnapshotHit}, triggered_hits::Vector{KM3io.TriggeredHit})
    triggermasks = Dict{Tuple{UInt8, Int32, Int32, UInt8}, Int64}()
    for hit ∈ triggered_hits
        triggermasks[(hit.channel_id, hit.dom_id, hit.t, hit.tot)] = hit.trigger_mask
    end
    n = length(snapshot_hits)
    hits = sizehint!(Vector{TriggeredHit}(), n)
    for hit in snapshot_hits
        channel_id = hit.channel_id
        dom_id = hit.dom_id
        t = hit.t
        tot = hit.tot
        triggermask = get(triggermasks, (channel_id, dom_id, t, tot), 0)
        push!(hits, TriggeredHit(dom_id, channel_id, t, tot, triggermask))
    end
    hits
end


"""
Calculates the average floor distance between neighboured modules.
"""
function floordist(det::Detector)
    floordistances = Float64[]
    for s ∈ det.strings
        # all the modules on the string, except the base module
        modules = [m for m in det if m.location.string == s && m.location.floor != 0 ]
        # collecting the z position for the same PMT channel (0) on each module
        push!(floordistances, mean(diff(sort(collect(m.pos.z for m ∈ modules)))))
    end
    mean(floordistances)
end

"""
Return the time slewing for a ToT.
"""
slew(tot::Integer) = @inbounds ifelse(tot < 256, SLEWS[tot + 1], SLEWS[end])
slew(tot::AbstractFloat) = slew(Int(floor(tot)))  # Jpp convention, not rounding but casting to int
slew(hit::AbstractHit) = slew(hit.tot)

const SLEWS = SVector(
    8.01, 7.52, 7.05, 6.59, 6.15, 5.74, 5.33, 4.95, 4.58, 4.22, 3.89, 3.56,
    3.25, 2.95, 2.66, 2.39, 2.12, 1.87, 1.63, 1.40, 1.19, 0.98, 0.78, 0.60,
    0.41, 0.24, 0.07, -0.10, -0.27, -0.43, -0.59, -0.75, -0.91, -1.08,
    -1.24, -1.41, -1.56, -1.71, -1.85, -1.98, -2.11, -2.23, -2.35, -2.47,
    -2.58, -2.69, -2.79, -2.89, -2.99, -3.09, -3.19, -3.28, -3.37, -3.46,
    -3.55, -3.64, -3.72, -3.80, -3.88, -3.96, -4.04, -4.12, -4.20, -4.27,
    -4.35, -4.42, -4.49, -4.56, -4.63, -4.70, -4.77, -4.84, -4.90, -4.97,
    -5.03, -5.10, -5.16, -5.22, -5.28, -5.34, -5.40, -5.46, -5.52, -5.58,
    -5.63, -5.69, -5.74, -5.80, -5.85, -5.91, -5.96, -6.01, -6.06, -6.11,
    -6.16, -6.21, -6.26, -6.31, -6.36, -6.41, -6.45, -6.50, -6.55, -6.59,
    -6.64, -6.68, -6.72, -6.77, -6.81, -6.85, -6.89, -6.93, -6.98, -7.02,
    -7.06, -7.09, -7.13, -7.17, -7.21, -7.25, -7.28, -7.32, -7.36, -7.39,
    -7.43, -7.46, -7.50, -7.53, -7.57, -7.60, -7.63, -7.66, -7.70, -7.73,
    -7.76, -7.79, -7.82, -7.85, -7.88, -7.91, -7.94, -7.97, -7.99, -8.02,
    -8.05, -8.07, -8.10, -8.13, -8.15, -8.18, -8.20, -8.23, -8.25, -8.28,
    -8.30, -8.32, -8.34, -8.37, -8.39, -8.41, -8.43, -8.45, -8.47, -8.49,
    -8.51, -8.53, -8.55, -8.57, -8.59, -8.61, -8.62, -8.64, -8.66, -8.67,
    -8.69, -8.70, -8.72, -8.74, -8.75, -8.76, -8.78, -8.79, -8.81, -8.82,
    -8.83, -8.84, -8.86, -8.87, -8.88, -8.89, -8.90, -8.92, -8.93, -8.94,
    -8.95, -8.96, -8.97, -8.98, -9.00, -9.01, -9.02, -9.04, -9.04, -9.04,
    -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04,
    -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04,
    -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04,
    -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04,
    -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04, -9.04,
    -9.04, -9.04
)

"""
Get the time of a hit with a rise time (slew) correction.
"""
@inline function Base.time(h::AbstractHit; correct_slew=true)
    correct_slew && return h.t - slew(h.tot)
    h.t
end


"""

The acoustics fit results of the dynamic calibration. The parameters describe
the shape of a string using the mechanical model.

"""
struct AcousticsFit
    id::Int       #  string identifier
    tx::Float64   #  slope dx/dz
    ty::Float64   #  slope dy/dz
    tx2::Float64  #  2nd order correction of slope dx/dz
    ty2::Float64  #  2nd order correction of slope dy/dz
    vs::Float64   #  stretching factor
end

struct DynamicPositionHeader
    detid::Int
    timestart::Float64
    timestop::Float64
    ndf::Float64
    npar::Int
    nhit::Int
    chi2::Float64
    numberOfIterations::Int
    nfit::Int
end


"""
A container type to store and access dynamic calibration results conveniently.
"""
struct DynamicPosition
    header::DynamicPositionHeader
    fits::Vector{AcousticsFit}
end

struct DynamicPositionSet
    calibrations::Vector{DynamicPosition}
end

function Base.show(io::IO, s::DynamicPositionSet)
    timestart = unix2datetime(minimum(s.header.timestart for s in s.calibrations))
    timestop = unix2datetime(maximum(s.header.timestop for s in s.calibrations))
    print(io, "DynamicPositionSet ($timestart - $timestop)")
end


"""
A single orientation measurement from a DOM compass, storing the quaternion
orientation (a, b, c, d correspond to q0, qx, qy, qz) and the timestamp.
"""
struct OrientationFit
    id::Int32        # module identifier
    t::Float64       # UNIX time [s]
    ns::UInt64       # sub-second nanoseconds
    q::Quaternion{Float64}  # orientation quaternion
    policy::Bool
end

"""
Meridian convergence angle for the ORCA site [rad].
From Jpp `JCompassSupportkit.hh`: `ORCA_MERIDIAN_CONVERGENCE_ANGLE_DEG = -2.022225934803321`.
"""
const ORCA_MERIDIAN_CONVERGENCE_ANGLE_RAD = -2.022225934803321 * π / 180

"""
Meridian convergence angle for the ARCA site [rad].
From Jpp `JCompassSupportkit.hh`: `ARCA_MERIDIAN_CONVERGENCE_ANGLE_DEG = +0.5773961143251137`.
"""
const ARCA_MERIDIAN_CONVERGENCE_ANGLE_RAD = +0.5773961143251137 * π / 180

# NOAA magnetic declination tables (from Jpp's JNOAA.hh).
# Columns: (unix_time_s, declination_deg).  Data runs from 2000-01-01 in
# ~monthly steps.  do_compile() in Jpp converts the degrees to radians; we do
# the same lazily in the interpolation function below.

const _ORCA_NOAA_TIMES = Int[
    946684800, 949363200, 951868800, 954547200, 957139200, 959817600,
    962409600, 965088000, 967766400, 970358400, 973036800, 975628800,
    978307200, 980985600, 983404800, 986083200, 988675200, 991353600,
    993945600, 996624000, 999302400, 1001894400, 1004572800, 1007164800,
    1009843200, 1012521600, 1014940800, 1017619200, 1020211200, 1022889600,
    1025481600, 1028160000, 1030838400, 1033430400, 1036108800, 1038700800,
    1041379200, 1044057600, 1046476800, 1049155200, 1051747200, 1054425600,
    1057017600, 1059696000, 1062374400, 1064966400, 1067644800, 1070236800,
    1072915200, 1075593600, 1078099200, 1080777600, 1083369600, 1086048000,
    1088640000, 1091318400, 1093996800, 1096588800, 1099267200, 1101859200,
    1104537600, 1107216000, 1109635200, 1112313600, 1114905600, 1117584000,
    1120176000, 1122854400, 1125532800, 1128124800, 1130803200, 1133395200,
    1136073600, 1138752000, 1141171200, 1143849600, 1146441600, 1149120000,
    1151712000, 1154390400, 1157068800, 1159660800, 1162339200, 1164931200,
    1167609600, 1170288000, 1172707200, 1175385600, 1177977600, 1180656000,
    1183248000, 1185926400, 1188604800, 1191196800, 1193875200, 1196467200,
    1199145600, 1201824000, 1204329600, 1207008000, 1209600000, 1212278400,
    1214870400, 1217548800, 1220227200, 1222819200, 1225497600, 1228089600,
    1230768000, 1233446400, 1235865600, 1238544000, 1241136000, 1243814400,
    1246406400, 1249084800, 1251763200, 1254355200, 1257033600, 1259625600,
    1262304000, 1264982400, 1267401600, 1270080000, 1272672000, 1275350400,
    1277942400, 1280620800, 1283299200, 1285891200, 1288569600, 1291161600,
    1293840000, 1296518400, 1298937600, 1301616000, 1304208000, 1306886400,
    1309478400, 1312156800, 1314835200, 1317427200, 1320105600, 1322697600,
    1325376000, 1328054400, 1330560000, 1333238400, 1335830400, 1338508800,
    1341100800, 1343779200, 1346457600, 1349049600, 1351728000, 1354320000,
    1356998400, 1359676800, 1362096000, 1364774400, 1367366400, 1370044800,
    1372636800, 1375315200, 1377993600, 1380585600, 1383264000, 1385856000,
    1388534400, 1391212800, 1393632000, 1396310400, 1398902400, 1401580800,
    1404172800, 1406851200, 1409529600, 1412121600, 1414800000, 1417392000,
    1420070400, 1422748800, 1425168000, 1427846400, 1430438400, 1433116800,
    1435708800, 1438387200, 1441065600, 1443657600, 1446336000, 1448928000,
    1451606400, 1454284800, 1456790400, 1459468800, 1462060800, 1464739200,
    1467331200, 1470009600, 1472688000, 1475280000, 1477958400, 1480550400,
    1483228800, 1485907200, 1488326400, 1491004800, 1493596800, 1496275200,
    1498867200, 1501545600, 1504224000, 1506816000, 1509494400, 1512086400,
    1514764800, 1517443200, 1519862400, 1522540800, 1525132800, 1527811200,
    1530403200, 1533081600, 1535760000, 1538352000, 1541030400, 1543622400,
    1546300800, 1548979200, 1551398400, 1554076800, 1556668800, 1559347200,
    1561939200, 1564617600, 1567296000, 1569888000, 1572566400, 1575158400,
    1577836800, 1580515200, 1583020800, 1585699200, 1588291200, 1590969600,
    1593561600, 1596240000, 1598918400, 1601510400, 1604188800, 1606780800,
    1609459200, 1612137600, 1614556800, 1617235200, 1619827200, 1622505600,
    1625097600, 1627776000, 1630454400, 1633046400, 1635724800, 1638316800,
    1640995200, 1643673600, 1646092800, 1648771200, 1651363200, 1654041600,
    1656633600, 1659312000, 1661990400, 1664582400, 1667260800, 1669852800,
    1672531200, 1675209600, 1677628800, 1680307200, 1682899200, 1685577600,
    1688169600, 1690848000, 1693526400, 1696118400, 1698796800, 1701388800,
    1704067200, 1706745600, 1709251200, 1711929600, 1714521600, 1717200000,
    1719792000, 1722470400, 1725148800, 1727740800, 1730419200, 1733011200,
    1735689600, 1738368000, 1740787200, 1743465600, 1746057600, 1748736000,
    1751328000, 1754006400, 1756684800, 1759276800, 1761955200, 1764547200,
    1767225600, 1769904000, 1772323200, 1775001600, 1777593600, 1780272000,
    1782864000, 1785542400, 1788220800, 1790812800, 1793491200, 1796083200,
    1798761600, 1801440000, 1803859200, 1806537600, 1809129600, 1811808000,
    1814400000, 1817078400, 1819756800, 1822348800, 1825027200, 1827619200,
    1830297600, 1832976000, 1835481600, 1838160000, 1840752000, 1843430400,
    1846022400, 1848700800, 1851379200, 1853971200, 1856649600, 1859241600,
    1861920000, 1864598400, 1867017600, 1869696000, 1872288000, 1874966400,
    1877558400, 1880236800, 1882915200, 1885507200, 1888185600, 1890777600,
]
const _ORCA_NOAA_DECL_DEG = Float64[
    -0.28317, -0.27442, -0.26625, -0.25751, -0.24905, -0.24031,
    -0.23186, -0.22312, -0.21438, -0.20593, -0.19719, -0.18874,
    -0.18001, -0.17125, -0.16334, -0.15459, -0.14612, -0.13736,
    -0.12889, -0.12014, -0.11139, -0.10292, -0.09417, -0.0857,
    -0.07695, -0.06821, -0.06031, -0.05156, -0.0431, -0.03435,
    -0.02589, -0.01715, -0.0084, 6e-05, 0.0088, 0.01726,
    0.026, 0.03474, 0.04263, 0.05137, 0.05982, 0.06856,
    0.07701, 0.08575, 0.09448, 0.10293, 0.11166, 0.12011,
    0.12885, 0.13755, 0.1457, 0.1544, 0.16282, 0.17153,
    0.17995, 0.18865, 0.19735, 0.20577, 0.21447, 0.22289,
    0.23159, 0.24086, 0.24923, 0.25849, 0.26745, 0.27672,
    0.28568, 0.29494, 0.3042, 0.31315, 0.32241, 0.33137,
    0.34062, 0.34987, 0.35823, 0.36748, 0.37643, 0.38568,
    0.39463, 0.40387, 0.41312, 0.42206, 0.43131, 0.44025,
    0.44949, 0.45873, 0.46707, 0.47631, 0.48525, 0.49448,
    0.50342, 0.51265, 0.52188, 0.53081, 0.54004, 0.54897,
    0.55819, 0.56739, 0.576, 0.5852, 0.5941, 0.60329,
    0.61219, 0.62138, 0.63057, 0.63947, 0.64866, 0.65755,
    0.66674, 0.67595, 0.68427, 0.69348, 0.70239, 0.71159,
    0.7205, 0.72971, 0.73891, 0.74781, 0.75701, 0.76592,
    0.77512, 0.78573, 0.79532, 0.80594, 0.81621, 0.82683,
    0.8371, 0.84771, 0.85832, 0.86858, 0.87919, 0.88946,
    0.90006, 0.91067, 0.92024, 0.93084, 0.9411, 0.9517,
    0.96196, 0.97255, 0.98315, 0.9934, 1.00399, 1.01424,
    1.02483, 1.03539, 1.04527, 1.05583, 1.06605, 1.0766,
    1.08682, 1.09737, 1.10792, 1.11813, 1.12868, 1.13889,
    1.14943, 1.16001, 1.16956, 1.18013, 1.19036, 1.20093,
    1.21116, 1.22172, 1.23229, 1.24251, 1.25308, 1.2633,
    1.27386, 1.28442, 1.29396, 1.30451, 1.31473, 1.32528,
    1.3355, 1.34605, 1.3566, 1.36681, 1.37736, 1.38756,
    1.39811, 1.41023, 1.42118, 1.43329, 1.44502, 1.45713,
    1.46886, 1.48097, 1.49308, 1.5048, 1.51691, 1.52862,
    1.54073, 1.5528, 1.56409, 1.57616, 1.58784, 1.5999,
    1.61158, 1.62364, 1.6357, 1.64737, 1.65943, 1.67109,
    1.68315, 1.69524, 1.70615, 1.71824, 1.72993, 1.74201,
    1.7537, 1.76578, 1.77786, 1.78954, 1.80162, 1.8133,
    1.82537, 1.83744, 1.84834, 1.86041, 1.87209, 1.88415,
    1.89583, 1.90789, 1.91995, 1.93162, 1.94367, 1.95534,
    1.9674, 1.97945, 1.99033, 2.00238, 2.01404, 2.02609,
    2.03775, 2.04979, 2.06184, 2.07349, 2.08553, 2.09718,
    2.10922, 2.11973, 2.12957, 2.14008, 2.15025, 2.16077,
    2.17094, 2.18145, 2.19196, 2.20213, 2.21263, 2.2228,
    2.23331, 2.24384, 2.25336, 2.26389, 2.27408, 2.28461,
    2.2948, 2.30533, 2.31586, 2.32605, 2.33658, 2.34676,
    2.35729, 2.36781, 2.37732, 2.38784, 2.39802, 2.40855,
    2.41873, 2.42925, 2.43977, 2.44994, 2.46046, 2.47064,
    2.48115, 2.49167, 2.50117, 2.51168, 2.52185, 2.53236,
    2.54254, 2.55305, 2.56356, 2.57373, 2.58423, 2.5944,
    2.60491, 2.61538, 2.62518, 2.63566, 2.64579, 2.65627,
    2.6664, 2.67687, 2.68734, 2.69748, 2.70795, 2.71808,
    2.72854, 2.73829, 2.74709, 2.75683, 2.76626, 2.77601,
    2.78543, 2.79518, 2.80492, 2.81434, 2.82408, 2.83351,
    2.84325, 2.85298, 2.86178, 2.87152, 2.88094, 2.89067,
    2.90009, 2.90983, 2.91956, 2.92898, 2.93871, 2.94813,
    2.95786, 2.96759, 2.97638, 2.98611, 2.99552, 3.00525,
    3.01467, 3.02439, 3.03412, 3.04353, 3.05326, 3.06267,
    3.07239, 3.08209, 3.09116, 3.10085, 3.11023, 3.11993,
    3.12931, 3.139, 3.14869, 3.15807, 3.16776, 3.17714,
    3.18683, 3.19654, 3.20532, 3.21503, 3.22443, 3.23415,
    3.24354, 3.25326, 3.26297, 3.27236, 3.28207, 3.29147,
]

const _ARCA_NOAA_TIMES = Int[
    946684800, 949363200, 951868800, 954547200, 957139200, 959817600,
    962409600, 965088000, 967766400, 970358400, 973036800, 975628800,
    978307200, 980985600, 983404800, 986083200, 988675200, 991353600,
    993945600, 996624000, 999302400, 1001894400, 1004572800, 1007164800,
    1009843200, 1012521600, 1014940800, 1017619200, 1020211200, 1022889600,
    1025481600, 1028160000, 1030838400, 1033430400, 1036108800, 1038700800,
    1041379200, 1044057600, 1046476800, 1049155200, 1051747200, 1054425600,
    1057017600, 1059696000, 1062374400, 1064966400, 1067644800, 1070236800,
    1072915200, 1075593600, 1078099200, 1080777600, 1083369600, 1086048000,
    1088640000, 1091318400, 1093996800, 1096588800, 1099267200, 1101859200,
    1104537600, 1107216000, 1109635200, 1112313600, 1114905600, 1117584000,
    1120176000, 1122854400, 1125532800, 1128124800, 1130803200, 1133395200,
    1136073600, 1138752000, 1141171200, 1143849600, 1146441600, 1149120000,
    1151712000, 1154390400, 1157068800, 1159660800, 1162339200, 1164931200,
    1167609600, 1170288000, 1172707200, 1175385600, 1177977600, 1180656000,
    1183248000, 1185926400, 1188604800, 1191196800, 1193875200, 1196467200,
    1199145600, 1201824000, 1204329600, 1207008000, 1209600000, 1212278400,
    1214870400, 1217548800, 1220227200, 1222819200, 1225497600, 1228089600,
    1230768000, 1233446400, 1235865600, 1238544000, 1241136000, 1243814400,
    1246406400, 1249084800, 1251763200, 1254355200, 1257033600, 1259625600,
    1262304000, 1264982400, 1267401600, 1270080000, 1272672000, 1275350400,
    1277942400, 1280620800, 1283299200, 1285891200, 1288569600, 1291161600,
    1293840000, 1296518400, 1298937600, 1301616000, 1304208000, 1306886400,
    1309478400, 1312156800, 1314835200, 1317427200, 1320105600, 1322697600,
    1325376000, 1328054400, 1330560000, 1333238400, 1335830400, 1338508800,
    1341100800, 1343779200, 1346457600, 1349049600, 1351728000, 1354320000,
    1356998400, 1359676800, 1362096000, 1364774400, 1367366400, 1370044800,
    1372636800, 1375315200, 1377993600, 1380585600, 1383264000, 1385856000,
    1388534400, 1391212800, 1393632000, 1396310400, 1398902400, 1401580800,
    1404172800, 1406851200, 1409529600, 1412121600, 1414800000, 1417392000,
    1420070400, 1422748800, 1425168000, 1427846400, 1430438400, 1433116800,
    1435708800, 1438387200, 1441065600, 1443657600, 1446336000, 1448928000,
    1451606400, 1454284800, 1456790400, 1459468800, 1462060800, 1464739200,
    1467331200, 1470009600, 1472688000, 1475280000, 1477958400, 1480550400,
    1483228800, 1485907200, 1488326400, 1491004800, 1493596800, 1496275200,
    1498867200, 1501545600, 1504224000, 1506816000, 1509494400, 1512086400,
    1514764800, 1517443200, 1519862400, 1522540800, 1525132800, 1527811200,
    1530403200, 1533081600, 1535760000, 1538352000, 1541030400, 1543622400,
    1546300800, 1548979200, 1551398400, 1554076800, 1556668800, 1559347200,
    1561939200, 1564617600, 1567296000, 1569888000, 1572566400, 1575158400,
    1577836800, 1580515200, 1583020800, 1585699200, 1588291200, 1590969600,
    1593561600, 1596240000, 1598918400, 1601510400, 1604188800, 1606780800,
    1609459200, 1612137600, 1614556800, 1617235200, 1619827200, 1622505600,
    1625097600, 1627776000, 1630454400, 1633046400, 1635724800, 1638316800,
    1640995200, 1643673600, 1646092800, 1648771200, 1651363200, 1654041600,
    1656633600, 1659312000, 1661990400, 1664582400, 1667260800, 1669852800,
    1672531200, 1675209600, 1677628800, 1680307200, 1682899200, 1685577600,
    1688169600, 1690848000, 1693526400, 1696118400, 1698796800, 1701388800,
    1704067200, 1706745600, 1709251200, 1711929600, 1714521600, 1717200000,
    1719792000, 1722470400, 1725148800, 1727740800, 1730419200, 1733011200,
    1735689600, 1738368000, 1740787200, 1743465600, 1746057600, 1748736000,
    1751328000, 1754006400, 1756684800, 1759276800, 1761955200, 1764547200,
    1767225600, 1769904000, 1772323200, 1775001600, 1777593600, 1780272000,
    1782864000, 1785542400, 1788220800, 1790812800, 1793491200, 1796083200,
    1798761600, 1801440000, 1803859200, 1806537600, 1809129600, 1811808000,
    1814400000, 1817078400, 1819756800, 1822348800, 1825027200, 1827619200,
    1830297600, 1832976000, 1835481600, 1838160000, 1840752000, 1843430400,
    1846022400, 1848700800, 1851379200, 1853971200, 1856649600, 1859241600,
    1861920000, 1864598400, 1867017600, 1869696000, 1872288000, 1874966400,
    1877558400, 1880236800, 1882915200, 1885507200, 1888185600, 1890777600,
]
const _ARCA_NOAA_DECL_DEG = Float64[
    1.67781, 1.6839, 1.68959, 1.69568, 1.70157, 1.70765,
    1.71354, 1.71962, 1.72571, 1.73159, 1.73767, 1.74356,
    1.74964, 1.75574, 1.76125, 1.76734, 1.77324, 1.77934,
    1.78524, 1.79134, 1.79743, 1.80333, 1.80942, 1.81532,
    1.82141, 1.82751, 1.83301, 1.8391, 1.845, 1.85109,
    1.85698, 1.86308, 1.86917, 1.87506, 1.88115, 1.88704,
    1.89313, 1.89922, 1.90472, 1.9108, 1.91669, 1.92278,
    1.92867, 1.93476, 1.94084, 1.94673, 1.95282, 1.9587,
    1.96479, 1.97085, 1.97653, 1.9826, 1.98847, 1.99453,
    2.0004, 2.00646, 2.01253, 2.0184, 2.02446, 2.03033,
    2.03639, 2.04402, 2.05091, 2.05854, 2.06593, 2.07356,
    2.08094, 2.08857, 2.09619, 2.10357, 2.1112, 2.11857,
    2.1262, 2.13382, 2.1407, 2.14832, 2.1557, 2.16332,
    2.17069, 2.17831, 2.18592, 2.19329, 2.20091, 2.20828,
    2.21589, 2.2235, 2.23038, 2.23799, 2.24535, 2.25296,
    2.26032, 2.26793, 2.27554, 2.2829, 2.2905, 2.29786,
    2.30547, 2.31305, 2.32014, 2.32772, 2.33505, 2.34263,
    2.34996, 2.35754, 2.36512, 2.37245, 2.38002, 2.38735,
    2.39492, 2.40251, 2.40937, 2.41696, 2.42431, 2.4319,
    2.43924, 2.44683, 2.45441, 2.46175, 2.46934, 2.47668,
    2.48426, 2.49296, 2.50081, 2.50951, 2.51792, 2.52662,
    2.53503, 2.54372, 2.55241, 2.56082, 2.56951, 2.57792,
    2.58661, 2.5953, 2.60314, 2.61183, 2.62023, 2.62891,
    2.63732, 2.646, 2.65468, 2.66308, 2.67176, 2.68015,
    2.68883, 2.69748, 2.70558, 2.71423, 2.7226, 2.73125,
    2.73962, 2.74826, 2.75691, 2.76528, 2.77392, 2.78229,
    2.79093, 2.79959, 2.80742, 2.81608, 2.82447, 2.83313,
    2.84151, 2.85017, 2.85883, 2.86721, 2.87587, 2.88424,
    2.8929, 2.90156, 2.90937, 2.91803, 2.9264, 2.93505,
    2.94342, 2.95207, 2.96072, 2.96909, 2.97773, 2.9861,
    2.99475, 3.00442, 3.01315, 3.02282, 3.03218, 3.04184,
    3.0512, 3.06086, 3.07052, 3.07987, 3.08954, 3.09888,
    3.10854, 3.11818, 3.12719, 3.13682, 3.14613, 3.15576,
    3.16508, 3.17471, 3.18433, 3.19364, 3.20327, 3.21258,
    3.2222, 3.23185, 3.24056, 3.2502, 3.25953, 3.26918,
    3.27851, 3.28815, 3.29779, 3.30711, 3.31675, 3.32608,
    3.33571, 3.34535, 3.35405, 3.36368, 3.373, 3.38263,
    3.39195, 3.40158, 3.4112, 3.42052, 3.43015, 3.43946,
    3.44908, 3.4587, 3.46739, 3.47701, 3.48632, 3.49594,
    3.50525, 3.51486, 3.52448, 3.53378, 3.54339, 3.5527,
    3.56231, 3.56927, 3.57579, 3.58275, 3.58949, 3.59645,
    3.60319, 3.61015, 3.61711, 3.62385, 3.63081, 3.63755,
    3.64451, 3.65148, 3.65779, 3.66476, 3.67151, 3.67849,
    3.68524, 3.69222, 3.69919, 3.70594, 3.71291, 3.71966,
    3.72663, 3.7336, 3.7399, 3.74687, 3.75361, 3.76058,
    3.76733, 3.7743, 3.78126, 3.78801, 3.79497, 3.80172,
    3.80868, 3.81565, 3.82194, 3.8289, 3.83564, 3.8426,
    3.84934, 3.8563, 3.86326, 3.87, 3.87696, 3.8837,
    3.89066, 3.89759, 3.90409, 3.91102, 3.91774, 3.92468,
    3.93139, 3.93833, 3.94526, 3.95197, 3.95891, 3.96562,
    3.97255, 3.97815, 3.98321, 3.9888, 3.99422, 3.99982,
    4.00523, 4.01083, 4.01642, 4.02184, 4.02743, 4.03285,
    4.03844, 4.04403, 4.04909, 4.05468, 4.06009, 4.06568,
    4.0711, 4.07669, 4.08228, 4.08769, 4.09328, 4.09869,
    4.10428, 4.10987, 4.11492, 4.12051, 4.12591, 4.1315,
    4.13691, 4.1425, 4.14809, 4.15349, 4.15908, 4.16448,
    4.17007, 4.17564, 4.18085, 4.18642, 4.19181, 4.19738,
    4.20277, 4.20834, 4.2139, 4.21929, 4.22486, 4.23025,
    4.23581, 4.24139, 4.24643, 4.25201, 4.25742, 4.263,
    4.26839, 4.27397, 4.27955, 4.28495, 4.29053, 4.29593,
]

function _noaa_interp(times::Vector{Int}, decl_deg::Vector{Float64}, t::Real)
    t < times[1]   && return decl_deg[1]   * (π/180)
    t > times[end] && return decl_deg[end] * (π/180)
    idx = searchsortedfirst(times, t)
    # exact hit
    times[idx] == t && return decl_deg[idx] * (π/180)
    # linear interpolation between idx-1 and idx
    t1, t2 = times[idx-1], times[idx]
    v1, v2 = decl_deg[idx-1], decl_deg[idx]
    (v1 + (v2 - v1) * (t - t1) / (t2 - t1)) * (π/180)
end

"""
    orca_magnetic_declination(t::Real) -> Float64

Return the magnetic declination [rad] at the ORCA site for UNIX time `t` [s],
using piecewise-linear interpolation of NOAA data (same table as Jpp's
`JORCAMagneticDeclination`).  Returns the boundary value outside the covered
range (2000-01-01 to ~2029-12-31).
"""
orca_magnetic_declination(t::Real) = _noaa_interp(_ORCA_NOAA_TIMES, _ORCA_NOAA_DECL_DEG, t)

"""
    arca_magnetic_declination(t::Real) -> Float64

Return the magnetic declination [rad] at the ARCA site for UNIX time `t` [s],
using piecewise-linear interpolation of NOAA data (same table as Jpp's
`JARCAMagneticDeclination`).  Returns the boundary value outside the covered
range (2000-01-01 to ~2029-12-31).
"""
arca_magnetic_declination(t::Real) = _noaa_interp(_ARCA_NOAA_TIMES, _ARCA_NOAA_DECL_DEG, t)
