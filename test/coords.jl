using KM3io
using KM3NeTTestData
using DelimitedFiles
using LinearAlgebra
using Test


@testset "UTM" begin
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

@testset "haversine" begin
    arca = LonLatExtended(0.2788259891652955, 0.6334183919376817, 1.3971407689009945, 0.010078736515781934)
    orca = LonLatExtended(0.10510862459055528, 0.7470155743891863, 1.4135447624739128, -0.03532879792661984)
    @test isapprox(1.1175809517026003e6, haversine(orca, arca))
    arca = LonLat(0.2788259891652955, 0.6334183919376817)
    orca = LonLatExtended(0.10510862459055528, 0.7470155743891863, 1.4135447624739128, -0.03532879792661984)
    @test isapprox(1.1175809517026003e6, haversine(orca, arca))
    @test isapprox(1.1175809517026003e6, haversine(arca, orca))

    @test isapprox(1.1175809517026003e3, haversine(arca, orca; R=6371))

    arca = Detector(datapath("detx", "KM3NeT_00000133_20221025.detx"))
    orca = Detector(datapath("detx", "D_ORCA006_t.A02181836.p.A02181837.r.A02182001.detx"))
    @test isapprox(1.1175809517026003e6, haversine(arca, orca))
end


@testset "rotations" begin
    l1 = LonLat(0.0, 0.0)
    l2 = LonLat(π, 0.0)
    R = rotmatrix(l1, l2)
    @test isapprox([0, 0, -1], R*Direction(0.0, 0.0, 1.0))
    @test isapprox([-1, 0, 0], R*Direction(1.0, 0.0, 0.0))
    @test isapprox([0, 1, 0], R*Direction(0.0, 1.0, 0.0))
    Rback = rotmatrix(l2, l1)
    @test I(3) == Rback*R

    arca = Detector(datapath("detx", "KM3NeT_00000133_20221025.detx"))
    orca = Detector(datapath("detx", "D_ORCA006_t.A02181836.p.A02181837.r.A02182001.detx"))
    R = rotmatrix(arca, orca)
    @test [0.13931456136972714, -0.10511045399085633, 0.9846538708867174] == R*Direction(0.0, 0.0, 1.0)
end
