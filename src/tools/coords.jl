"""
Calculate the longitude and latitude for a given [`UTMPosition`](@ref).

This implementation is the one in [`aanet`](https://git.km3net.de/common/aanet) but does
not calculate the point scale factor and the meridian convergence angle. In `aanet`, those
are calculated separately. The returned [`LonLat`](@ref) has those values set to `0` in
this case.

The original source of the implementation is unknown.
There is a very similar code from 2013 in https://github.com/pwcazenave/fvcom-toolbox/blob/master/utilities/utm2deg.m which states it's based on the "UTMIP.m function by Gabriel Ruiz Martinez". This leads to this code from 2006 https://de.mathworks.com/matlabcentral/fileexchange/10914-utm2deg from Rafael Palacios with another reference to the "UTMIP.m function by Gabriel Ruiz Martinez".

Unfortunately, the original UTMIP.m could not be found yet. Further findings:

From 2018 on the MATLAB forum:
https://de.mathworks.com/matlabcentral/answers/381403-coordinate-transformation-geographic-to-projected-utm
Another from from 2020 written in C# on a Korean website: https://www.iotworks.co.kr/xe/index.php?mid=board_hCcz16&document_srl=36066
and another one (basically the same) in a document from the university of Catalunya (Escola d'Enginyeria de Telecommunicació i Aerospacial de Castelldefels) https://upcommons.upc.edu/bitstream/handle/2117/349264/memoria.pdf;jsessionid=89D86F73867CB1B216B1C28D54DDCB3B?sequence=1 (page 220ff)
There is a very similar code from 2020 written in C# on a Korean website: https://www.iotworks.co.kr/xe/index.php?mid=board_hCcz16&document_srl=36066
and another one (basically the same) in a document from the university of Catalunya (Escola d'Enginyeria de Telecommunicació i Aerospacial de Castelldefels) https://upcommons.upc.edu/bitstream/handle/2117/349264/memoria.pdf;jsessionid=89D86F73867CB1B216B1C28D54DDCB3B?sequence=1 (page 220ff)
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

    return LonLat(longitude * π / 180, latitude * π / 180)
end
lonlat_aanet(d::Detector; kwargs...) = lonlat_aanet(d.pos; kwargs...)

"""

Calculates the Haversine distance (in m) between two detector locations.

The implementation is taken from
[Distances.jl](https://github.com/JuliaStats/Distances.jl).

"""
KM3Base.haversine(d₁::Detector, d₂::Detector) = haversine(lonlat(d₁), lonlat(d₂))

"""

Generate a rotation matrix to transfrom local ENU (East x, North y, Up z)
coordinates from one detector to another detector's local ENU coordinate
system.

"""
KM3Base.rotmatrix(from::Detector, to::Detector) = rotmatrix(lonlat(from), lonlat(to))
