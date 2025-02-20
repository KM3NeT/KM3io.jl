"""
A position in longitude and latitude.
"""
struct LonLat
    lon::Float64
    lat::Float64
end

"""
Calculate the longitude and latitude for a given [`UTMPosition`](@ref).
"""
function lonlat end
function lonlat(utm::UTMPosition)
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

    return LonLat(longitude * π / 180, latitude * π / 180)
end
lonlat(d::Detector; kwargs...) = lonlat(d.pos; kwargs...)
