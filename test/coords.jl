using KM3io
using KM3NeTTestData
using DelimitedFiles
using Test


@testset "DATX" begin
    detector = Detector(datapath("detx", "KM3NeT_00000133_20221025.detx"))
    data, header = readdlm(datapath("astro", "local2eq_aanet_2.7.0.csv"), ','; header=true)

    headeridx(column_name) = findfirst(isequal(column_name), header).I |> last

    idx_utm_easting = headeridx("utm_easting")
    idx_utm_northing = headeridx("utm_northing")
    idx_utm_z = headeridx("utm_northing")
    idx_utm_zone = headeridx("utm_zone")
    idx_det_latitude = headeridx("det_latitude")
    idx_det_longitude = headeridx("det_longitude")
    idx_meridian_convergence = headeridx("meridian_convergence")

    for row in eachrow(data)
        ll = lonlat(UTMPosition(row[idx_utm_easting], row[idx_utm_northing], row[idx_utm_zone], 'N', row[idx_utm_z]))
        @test isapprox(ll.lat, row[idx_det_latitude], atol=1e-4)
        @test isapprox(ll.lon, row[idx_det_longitude], atol=1e-4)
        @test isapprox(ll.meridian_convergence, row[idx_meridian_convergence], atol=1e-5)
    end

end
