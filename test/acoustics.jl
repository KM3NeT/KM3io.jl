using KM3io
using KM3NeTTestData
using Test

const SAMPLES_DIR = joinpath(@__DIR__, "samples")

@testset "acoustics" begin
    signal = AcousticSignal(joinpath(SAMPLES_DIR, "DOM_808956920_CH1_1608751683.bin"))
    @test 808956920 == signal.dom_id
    @test 0x5fe39a3f == signal.utc_seconds
    @test 0x00020000 == signal.samples
    @test 123260 == length(signal.pcm)
    @test 0.0031588078f0 == signal.pcm[1]
    @test 0.0033951998f0 == signal.pcm[end]

    mod = DetectorModule(1, Position(0.0, 0.0, 0.0), Location(0, 0), 0, PMT[], Quaternion(0, 0, 0, 0), 0, 0)
    @test hydrophoneenabled(mod)
    @test piezoenabled(mod)

    status = 1 << KM3io.MODULE_STATUS.PIEZO_DISABLE
    mod = DetectorModule(1, Position(0.0, 0.0, 0.0), Location(0, 0), 0, PMT[], Quaternion(0, 0, 0, 0), status, 0)
    @test !piezoenabled(mod)
    @test hydrophoneenabled(mod)

    status = 1 << KM3io.MODULE_STATUS.HYDROPHONE_DISABLE
    mod = DetectorModule(1, Position(0.0, 0.0, 0.0), Location(0, 0), 0, PMT[], Quaternion(0, 0, 0, 0), status, 0)
    @test piezoenabled(mod)
    @test !hydrophoneenabled(mod)

    status = (1 << KM3io.MODULE_STATUS.HYDROPHONE_DISABLE) | (1 << KM3io.MODULE_STATUS.PIEZO_DISABLE)
    mod = DetectorModule(1, Position(0.0, 0.0, 0.0), Location(0, 0), 0, PMT[], Quaternion(0, 0, 0, 0), status, 0)
    @test !piezoenabled(mod)
    @test !hydrophoneenabled(mod)
end

@testset "Acoustics File" begin
    f = DynamicPositionFile(datapath("acoustics", "KM3NeT_00000267_00024724.acoustic-events_A_2.0.0.root"))
    @test 9 == f[1].id
    @test 267 == f[1].det_id
    @test 3 == f[1].overlays
    @test 0 == f[1].counter
    @test 23 == f[end].id
    @test 1427 == f[end].counter
    @test 518 == length(f)
    @test 403 == length(f[1])
    @test 403 == length(f[1].transmissions)
    @test 401 == length(f[end])
    @test 5 == length(f[5:9])
    @test 808957378 == f[1].transmissions[1].id
    @test 24724 == f[1].transmissions[1].run
    @test 4707.0 == f[1].transmissions[1].q
    @test 0.0 == f[1].transmissions[1].w
    @test isapprox(1.7559723249875731e9, f[1].transmissions[1].toa)
    @test isapprox(1.755972324518772e9, f[1].transmissions[1].toe)

    n = 0
    for event in f
        n += length(event)
    end
    @test 208111 == n
end

@testset "DynamicPositionFile with mechanical model" begin
    f = DynamicPositionFile(datapath("acoustics", "mechanical_model.root"))

    # file has an empty ACOUSTICS tree and a populated ACOUSTICS_FIT tree
    @test 0 == length(f)
    @test !isnothing(f._transmissions)
    @test !isnothing(f._calibration_sets)

    cs = f._calibration_sets
    @test 14 == length(cs.calibrations)

    h = cs.calibrations[1].header
    @test 148 == h.detid
    @test 1.684305246695606e9 ≈ h.timestart
    @test 1.684305846765883e9 ≈ h.timestop
    @test 7909 == h.nhit
    @test 7909 == h.nfit
    @test 104 == h.npar
    @test 7574.75 ≈ h.ndf atol=1e-2
    @test 3422.471 ≈ h.chi2 atol=1e-3
    @test 19 == h.numberOfIterations

    fits = cs.calibrations[1].fits
    @test 14 == length(fits)
    @test 10 == fits[1].id
    @test 0.004444270786890379 ≈ fits[1].tx
    @test -0.002677338350879895 ≈ fits[1].ty
    @test -5.848360031938995e-6 ≈ fits[1].tx2
    @test -3.1562347126287645e-6 ≈ fits[1].ty2
    @test 6.013913271231749e-6 ≈ fits[1].vs
    @test 31 == fits[end].id

    @test 148 == cs.calibrations[end].header.detid
    @test 1.6843131642554398e9 ≈ cs.calibrations[end].header.timestart

    m = detector_mechanics(f)
    @test 0.00311 ≈ m.default.a
    @test 85.966 ≈ m.default.b
    @test 1 == length(m.stringparams)
    @test 0.00087 ≈ m[9].a
    @test 267.054 ≈ m[9].b
end
