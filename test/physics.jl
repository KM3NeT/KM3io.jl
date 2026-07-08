using KM3io
import KM3io: CherenkovPhoton
using KM3NeTTestData
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
        FitInformation([0]),
        0
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

@testset "cherenkov() water index" begin
    track = Trk(
        0,
        Position(1.7524502152598151, 39.06202405657308, 130.44049806891948),
        Direction(0.028617421257374293, -0.489704257367248, -0.8714188335794505),
        70311441.452294,
        0,
        0,
        0,
        0,
        [0],
        FitInformation([0]),
        0
    )
    hit = CalibratedHit(0, 0, 0, 0, 0, 0, Position(19.522, -12.053, 76.662), Direction(-0.39, 0.735, 0.555))

    # The default Water reproduces the previous constant-based behaviour exactly.
    @test cherenkov(track, hit) == cherenkov(track, hit, Water())
    @test cherenkov(track, [hit]) == cherenkov(track, [hit], Water())
    @test Water().n_phase == KM3io.Constants.WATER_INDEX
    @test Water().n_group == KM3io.Constants.WATER_INDEX + KM3io.Constants.DN_DL

    # Constructor shorthands.
    @test Water(n=1.35).n_phase == 1.35
    @test Water(n=1.35).n_group == 1.35 + KM3io.Constants.DN_DL
    @test Water(n_phase=1.35, n_group=1.40).n_phase == 1.35
    @test Water(n_phase=1.35, n_group=1.40).n_group == 1.40

    γ = cherenkov(track, hit)

    # The phase index sets the Cherenkov angle (geometry) but not d_closest.
    γ_phase = cherenkov(track, hit, Water(n_phase=1.40, n_group=Water().n_group))
    @test γ.d_closest == γ_phase.d_closest
    @test γ.d_photon != γ_phase.d_photon
    @test γ.d_track != γ_phase.d_track
    @test γ.dir != γ_phase.dir
    # A larger phase index means a larger angle, larger sin and a shorter photon path.
    @test γ_phase.d_photon < γ.d_photon

    # The group index only affects timing; all geometry is left untouched.
    γ_group = cherenkov(track, hit, Water(n_phase=Water().n_phase, n_group=1.50))
    @test γ.d_closest == γ_group.d_closest
    @test γ.d_photon == γ_group.d_photon
    @test γ.d_track == γ_group.d_track
    @test γ.dir == γ_group.dir
    @test γ.t != γ_group.t
    # A larger group index means slower photons and a later arrival time.
    @test γ_group.t > γ.t

    # The Track callable forwards the water argument too.
    ctrack = Track(track.dir, track.pos, track.t)
    @test ctrack(hit, Water(n=1.40)) == cherenkov(ctrack, hit, Water(n=1.40))
    @test ctrack(hit.pos, Water(n=1.40)).d_photon == cherenkov(ctrack, hit.pos, Water(n=1.40)).d_photon
    @test isnan(ctrack(hit.pos, Water(n=1.40)).impact_angle)
end

@testset "water dispersion model" begin
    # At the reference wavelength the Jpp dispersion reproduces the aanet indices.
    w = Water(λ=KM3io.Constants.REFERENCE_WAVELENGTH)
    @test w.n_phase ≈ KM3io.Constants.WATER_INDEX atol=1e-3
    @test w.n_group ≈ KM3io.Constants.WATER_INDEX + KM3io.Constants.DN_DL atol=1e-3

    # Longer wavelength -> smaller index (normal dispersion).
    @test Water(λ=600).n_phase < Water(λ=400).n_phase
    @test Water(λ=600).n_group < Water(λ=400).n_group
    # Higher ambient pressure -> larger index.
    @test Water(λ=460, P=400).n_phase > Water(λ=460, P=240).n_phase

    # The bare Water() still returns the exact aanet constants, not the model.
    @test Water().n_phase == KM3io.Constants.WATER_INDEX
    @test Water().n_group == KM3io.Constants.WATER_INDEX + KM3io.Constants.DN_DL

    # Hydrostatic pressure: 1 atm at the surface, monotonically increasing.
    @test KM3io.pressure_at_depth(0) ≈ 1.0
    @test KM3io.pressure_at_depth(2440) ≈ 246.13 atol=0.1
    @test KM3io.pressure_at_depth(3450) > KM3io.pressure_at_depth(2440)

    # Site constants: ARCA (3450 m) is deeper, hence higher pressure and index.
    @test WaterARCA.n_phase > WaterORCA.n_phase
    @test WaterARCA.n_group > WaterORCA.n_group
    @test WaterORCA == Water(λ=KM3io.Constants.REFERENCE_WAVELENGTH, P=KM3io.pressure_at_depth(2440.0))
    @test WaterARCA == Water(λ=KM3io.Constants.REFERENCE_WAVELENGTH, P=KM3io.pressure_at_depth(3450.0))
    @test WaterORCA.n_phase ≈ 1.349941 atol=1e-5
    @test WaterORCA.n_group ≈ 1.379806 atol=1e-5
    @test WaterARCA.n_phase ≈ 1.351362 atol=1e-5
    @test WaterARCA.n_group ≈ 1.381226 atol=1e-5
end

@testset "cherenkov() slewing correction" begin
    track = Trk(
        0,
        Position(1.7524502152598151, 39.06202405657308, 130.44049806891948),
        Direction(0.028617421257374293, -0.489704257367248, -0.8714188335794505),
        70311441.452294,
        0,
        0,
        0,
        0,
        [0],
        FitInformation([0]),
        0
    )
    # A hit with a non-zero ToT (27) so the slewing lookup is exercised, and a
    # non-zero hit time so the time residual is well defined.
    hit = CalibratedHit(0, 0, 0, 27, 0, 100.0, Position(19.522, -12.053, 76.662), Direction(-0.39, 0.735, 0.555))

    γ_raw = cherenkov(track, hit; correct_slew=false)
    γ_slew = cherenkov(track, hit; correct_slew=true)

    # Slewing is off by default: the result equals the explicit raw call and uses
    # the unmodified hit time (previous KM3io behaviour).
    @test cherenkov(track, hit).Δt == γ_raw.Δt
    @test γ_raw.Δt == hit.t - γ_raw.t

    # Enabling it subtracts slew(tot) from the hit time, shifting only Δt.
    @test KM3io.slew(hit.tot) != 0
    @test γ_slew.Δt ≈ γ_raw.Δt - KM3io.slew(hit.tot)
    @test γ_slew.d_closest == γ_raw.d_closest
    @test γ_slew.d_photon == γ_raw.d_photon
    @test γ_slew.d_track == γ_raw.d_track
    @test γ_slew.t == γ_raw.t
    @test γ_slew.dir == γ_raw.dir

    # The flag is forwarded through the vector method and both Track callables.
    # This also guards the vector Track callable against a keyword regression.
    ctrack = Track(track.dir, track.pos, track.t)
    @test cherenkov(track, [hit]; correct_slew=true)[1].Δt == γ_slew.Δt
    @test cherenkov(track, [hit])[1].Δt == γ_raw.Δt
    @test ctrack(hit; correct_slew=true).Δt == γ_slew.Δt
    @test ctrack(hit).Δt == γ_raw.Δt
    @test ctrack([hit]; correct_slew=true)[1].Δt == γ_slew.Δt
    @test ctrack([hit])[1].Δt == γ_raw.Δt
end

@testset "TimeConverter" begin
    tc = TimeConverter(9.25879610631827e9, 93)
    @test tc.offset ≈ 5.879610631826973e7
    @test TimeConverter(9.25879610631827e9, 93) == TimeConverter(5.879610631826973e7)
    # frame_index <= 0 -> frame_start is 0
    @test TimeConverter(1234.0, 0).offset == 1234.0
    @test TimeConverter(1234.0, -5).offset == 1234.0
    # directions and round trip (offset ~5.9e7 dominates, so round trip is approximate)
    @test mc2daq(tc, 0.0) == tc.offset
    @test daq2mc(tc, tc.offset) == 0.0
    @test daq2mc(tc, mc2daq(tc, 123.4)) ≈ 123.4
    # broadcasting (guards the broadcastable definition)
    @test mc2daq.(tc, [0.0, 10.0]) == [tc.offset, tc.offset + 10.0]

    f = ROOTFile(datapath("offline", "mcv6.0.gsg_muon_highE-CC_50-500GeV.km3sim.jterbr00008357.jorcarec.aanet.905.root"))
    evt = first(f.offline)
    tcE = TimeConverter(evt)
    @test evt.frame_index == 93
    @test tcE.offset ≈ 5.879610631826973e7
    @test tcE == TimeConverter(evt.mc_t, evt.frame_index)
    # track/hit sugar pulls .t
    @test mc2daq(tcE, evt.mc_trks[1]) == mc2daq(tcE, evt.mc_trks[1].t)
    # the converted MC-truth muon time lands just before the first triggered hit
    t_daq = mc2daq(tcE, evt.mc_trks[1])
    firsthit = minimum(h.t for h in filter(triggered, evt.hits))
    @test 0 < firsthit - t_daq < 1e4
    close(f)
end
