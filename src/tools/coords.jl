"""
A position in longitude and latitude.
"""
struct LonLat
    lon::Float64
    lat::Float64
    point_scale_factor::Float64
    meridian_convergence::Float64
end

"""
Calculate the longitude and latitude for a given [`UTMPosition`](@ref).
Distances are in km and angles in radians.

These formulae are truncated version of Transverse Mercator: flattening series,
which were originally derived by Johann Heinrich Louis Krüger in 1912.
(https://apps.dtic.mil/sti/tr/pdf/ADA266497.pdf). They are accurate to around a
millimeter within 3000 km of the central meridian.
"""
function lonlat end
function lonlat(utm::UTMPosition)::LonLat
    N = utm.northing / 1000
    E = utm.easting / 1000
    hemi = isnorthern(utm) ? +1 : -1
    N₀ = isnorthern(utm) ? 0 : 10000  # [km]
    a = 6378.137  # [km]
    f = 1/298.257223563  # flattening
    E₀ = 500  # [km]
    k₀ = 0.9996

    n = f/(2-f)
    A = a/(1+n) * (1 + n^2/4 + n^4/64)  # + ...?

    # used in backwards conversion, leaving it here for later ;)
    # α = SVector(
    #     (1/2)n - (2/3)n^2 + (5/16)n^3,
    #     (13/48)n^2 - (3/5)n^3,
    #     (61/240)n^3
    # )

    β = SVector(
        (1/2)n - (2/3)n^2 + (37/96)n^3,
        (1/48)n^2 + (1/15)n^3,
        (17/480)n^3
    )

    δ = SVector(
        2n - (2/3)n^2 - 2n^3,
        (7/3)n^2 - (8/5)n^3,
        (56/15)n^3
    )

    ξ = (N - N₀)/(k₀ * A)
    η = (E - E₀)/(k₀ * A)
    ξ′ = ξ - sum(β[j] * sin(2j*ξ) * cosh(2j*η) for j ∈ 1:3)
    η′ = η - sum(β[j] * cos(2j*ξ) * sinh(2j*η) for j ∈ 1:3)
    σ′ = 1 - sum(2j*β[j] * cos(2j*ξ) * cosh(2j*η) for j ∈ 1:3)
    τ′ = sum(2j*β[j] * sin(2j*ξ) * sinh(2j*η) for j ∈ 1:3)
    χ = asin(sin(ξ′)/cosh(η′))

    ϕ = χ + sum(δ[j] * sin(2j*χ) for j ∈ 1:3)  # latitude [rad]
    λ₀ = deg2rad(utm.zone_number * 6 - 183)
    λ = λ₀ + atan(sinh(η′)/cos(ξ′))  # longitude [rad]
    # point scale factor
    k = k₀*A/a * √( (1 + ((1 - n)/(1 + n))*tan(ϕ))^2 * (cos(ξ′)^2 + sinh(η′)^2)/(σ′^2 + τ′^2) )
    # meridian convergence
    γ = hemi * atan( (τ′ + σ′*tan(ξ′)*tanh(η′)) / (σ′ + τ′*tan(ξ′)*tanh(η′)) )
    return LonLat(λ, ϕ, k, γ)
end
lonlat(d::Detector; kwargs...) = lonlat(d.pos; kwargs...)


"""
Calculate the longitude and latitude for a given [`UTMPosition`](@ref).

This implementation is the one in [`aanet`](https://git.km3net.de/common/aanet) but does
not calculate the point scale factor and the meridian convergence angle. In `aanet`, those
are calculated separately. The returned [`LonLat`](@ref) has those values set to `0` in
this case.
"""
function lonlat_aanet(utm::UTMPosition)::LonLat
    diflat = -0.00066286966871111111111111111111111111
    diflon = -0.0003868060578

    c_sa = 6378137.0
    c_sb = 6356752.314245
    e2 = sqrt((c_sa^2 - c_sb^2)) / c_sb
    e2cuadrada = e2^2
    c = c_sa^2 / c_sb
    x = utm.easting - 500000
    y = isnorthern(utm) ? utm.northing : utm.northing - 10000000  # TODO: is this correct?

    s = (utm.zone_number * 6.0) - 183.0
    lat = y / (c_sa * 0.9996)
    v = (c / sqrt(1 + e2cuadrada * cos(lat)^2)) * 0.9996
    a = x / v
    a1 = sin(2 * lat)
    a2 = a1 * cos(lat)^2
    j2 = lat + (a1 / 2.0)
    j4 = (3 * j2 + a2) / 4.0
    j6 = (5 * j4 + (a2 * cos(lat)^2)) / 3.0
    α = (3.0 / 4.0) * e2cuadrada
    β = (5.0 / 3.0) * α^2
    γ = (35.0 / 27.0) * α^3
    bm = 0.9996 * c * (lat - α * j2 + β * j4 - γ * j6)
    b = (y - bm) / v
    ϵ = ((e2cuadrada * a^2) / 2.0) * cos(lat)^2
    eps = a * (1 - (ϵ / 3.0))
    nab = (b * (1 - ϵ)) + lat
    senoheps = (exp(eps) - exp(-eps)) / 2.0
    δ = atan(senoheps / cos(nab))
    tao = atan(cos(δ) * tan(nab))

    longitude = ((δ * (180.0 / π)) + s) + diflon
    latitude = ((lat + (1 + e2cuadrada * cos(lat)^2 - (3.0 / 2.0) * e2cuadrada * sin(lat) * cos(lat) * (tao - lat)) * (tao - lat)) * (180.0 / π)) + diflat

    return LonLat(longitude * π / 180, latitude * π / 180, 0, 0)
end
