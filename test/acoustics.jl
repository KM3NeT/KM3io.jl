using KM3io
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

    mod = DetectorModule(1, UTMPosition(0, 0, 0), Location(0, 0), 0, PMT[], missing, 0, 0)
    @test hydrophoneenabled(mod)
    @test piezoenabled(mod)

    status = 1 << KM3io.MODULE_STATUS.PIEZO_DISABLE
    mod = DetectorModule(1, UTMPosition(0, 0, 0), Location(0, 0), 0, PMT[], missing, status, 0)
    @test !piezoenabled(mod)
    @test hydrophoneenabled(mod)

    status = 1 << KM3io.MODULE_STATUS.HYDROPHONE_DISABLE
    mod = DetectorModule(1, UTMPosition(0, 0, 0), Location(0, 0), 0, PMT[], missing, status, 0)
    @test piezoenabled(mod)
    @test !hydrophoneenabled(mod)

    status = (1 << KM3io.MODULE_STATUS.HYDROPHONE_DISABLE) | (1 << KM3io.MODULE_STATUS.PIEZO_DISABLE)
    mod = DetectorModule(1, UTMPosition(0, 0, 0), Location(0, 0), 0, PMT[], missing, status, 0)
    @test !piezoenabled(mod)
    @test !hydrophoneenabled(mod)
end
