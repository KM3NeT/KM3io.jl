using KM3io
import KM3io: CherenkovPhoton
using Test

@testset "cherenkov()" begin
    hits = [
        CalibratedHit(0, 0, 0, 0, 0, 0, Position(19.522, -12.053, 76.662), Direction(-0.39, 0.735, 0.555)),
        CalibratedHit(0, 0, 0, 0, 0, 0, Position(19.435, -12.194, 76.662), Direction(-0.831, 0.03, 0.555)),
    ]
    track = Trk(
        0,
        Position(1.7524502152598151,39.06202405657308,130.44049806891948),
        Direction(0.028617421257374293,-0.489704257367248,-0.8714188335794505),
        70311441.452294,
        0,
        0,
        0,
        0,
        [0],
        FitInformation([0])
    )

    γs = cherenkov(track, hits)
    @test 2 == length(γs)
    @test 24.049593557846112 ≈ γs[1].d_closest
    @test 24.085065395206847 ≈ γs[2].d_closest

    @test 35.80244420413484 ≈ γs[1].d_photon
    @test 35.855250854478896 ≈ γs[2].d_photon

    @test 45.88106599210481 ≈ γs[1].d_track
    @test 45.90850564175342 ≈ γs[2].d_track

    @test 70311759.26448613 ≈ γs[1].t
    @test 70311759.59904088 ≈ γs[2].t

    @test -0.98123942583677 ≈ γs[1].impact_angle
    @test -0.6166369315726149 ≈ γs[2].impact_angle

    @test Direction(0.45964884122649263, -0.8001372907490844, -0.3853612055096594) ≈ γs[1].dir
    @test Direction(0.45652355929477095,-0.8025165828910586, -0.38412676812960095) ≈ γs[2].dir

    @test γs[1] == cherenkov(track, hits[1])
    @test γs[2] == cherenkov(track, hits[2])

    cγ = cherenkov(track, hits[1].pos)
    for fieldname ∈ fieldnames(CherenkovPhoton)
        if fieldname == :impact_angle
            @test isnan(getfield(cγ, fieldname))
            continue
        end
        @test getfield(γs[1], fieldname) == getfield(cγ, fieldname)
    end

end


@testset "azimuth()" begin
    @test π/2*3 == azimuth(Direction(0.0, 1.0, 0.0))
    @test 0 ≈ azimuth(Direction(1.0, 0.0, 0.0))
    @test π/2 ≈ azimuth(Direction(0.0, -1.0, 0.0))
    @test 0 ≈ azimuth(Direction(-1.0, 0.0, 0.0))
end

@testset "zenith()" begin
    @test 0.0 == zenith(Direction(0.0, 0.0, -1.0))
    @test π/2 == zenith(Direction(0.0, 1.0, 0.0))
    @test π/2 == zenith(Direction(1.0, 1.0, 0.0))
    @test π ≈ zenith(Direction(0.0, 0.0, 1.0))
end

@testset "phi()" begin
    @test π/2 == phi(Direction(0.0, 1.0, 0.0))
    @test 0 ≈ phi(Direction(1.0, 0.0, 0.0))
    @test -π/2 ≈ phi(Direction(0.0, -1.0, 0.0))
    @test π ≈ phi(Direction(-1.0, 0.0, 0.0))
end

@testset "theta()" begin
    @test π ≈ theta(Direction(0.0, 0.0, -1.0))
    @test π/2 == theta(Direction(0.0, 1.0, 0.0))
    @test π/2 == theta(Direction(1.0, 1.0, 0.0))
    @test 0.0 == theta(Direction(0.0, 0.0, 1.0))
end
