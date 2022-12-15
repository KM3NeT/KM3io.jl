using KM3io
using Test

const SAMPLES_DIR = joinpath(@__DIR__, "samples")

@testset "acoustics" begin
    signal = read(joinpath(SAMPLES_DIR, "DOM_808956920_CH1_1608751683.bin"), KM3io.AcousticSignal)
    @test 808956920 == signal.dom_id
    @test 0x5fe39a3f == signal.utc_seconds
    @test 0x00020000 == signal.samples
    @test 123260 == length(signal.pcm)
    @test 0.0031588078f0 == signal.pcm[1]
    @test 0.0033951998f0 == signal.pcm[end]
end
