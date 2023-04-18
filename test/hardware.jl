using Test

using KM3io
using Dates

const SAMPLES_DIR = joinpath(@__DIR__, "samples")


@testset "io" begin
    @testset "DETX parsing" begin
        for version ∈ 1:5
            d = Detector(joinpath(SAMPLES_DIR, "v$(version).detx"))

            @test version == d.version

            mods = DetectorModule[]
            for mod in d
                push!(mods, mod)
            end

            if version < 4
                # no base modules in DETX version <4
                @test 342 == length(d)
                @test 342 == length(d.modules)
                @test DetectorModule == eltype(d)
            else
                @test 361 == length(mods)
                @test 106.95 ≈ d.modules[808469291].pos.y  # base module
                @test 97.3720395 ≈ d.modules[808974928].pos.z  # base module
                @test 0.0 == d.modules[808469291].t₀  # base module
            end

            @test 116.600 ≈ d.modules[808992603].pos.x atol=1e-5  # optical module

            if version > 3
                @test Quaternion(1, 0, 0, 0) ≈ d.modules[808995481].q
            end

            if version > 4
                # module status introduced in v5
                @test 0 == d.modules[808966287].status
            end

            if version > 1
                @test UTMPosition(587600, 4016800, -3450) ≈ d.pos
                @test 1654207200.0 == datetime2unix(d.validity.from)
                @test 9999999999.0 == datetime2unix(d.validity.to)
            end

            @test 31 == d.modules[808992603].n_pmts
            @test 30 ≈ d.modules[817287557].location.string
            @test 18 ≈ d.modules[817287557].location.floor

            @test 478392.31980645156 ≈ d.modules[808992603].t₀

            @test 9 == d.strings[1]
            @test 30 == d.strings[end]
            @test 19 == length(d.strings)

        end

        comments = Detector(joinpath(SAMPLES_DIR, "v3.detx")).comments
        @test 2 == length(comments)
        @test "This is a comment" == comments[1]
        @test "This is another comment" == comments[2]
    end
    @testset "DETX writing" begin
        for from_version ∈ 1:5
            for to_version ∈ 1:5
                out = tempname()
                d₀ = Detector(joinpath(SAMPLES_DIR, "v$(from_version).detx"))
                write(out, d₀; version=to_version)
                d = Detector(out)
                @test length(d₀) == length(d)
                if to_version >= from_version
                    for module_id ∈ collect(keys(d₀.modules))[:23]
                        @test d₀.modules[module_id].pos ≈ d.modules[module_id].pos
                        if from_version >= 3
                            @test d₀.modules[module_id].t₀ ≈ d.modules[module_id].t₀
                        end
                    end
                end
            end
        end
    end
    @testset "hydrophones" begin
        hydrophones = read(joinpath(SAMPLES_DIR, "hydrophone.txt"), Hydrophone)
        @test 19 == length(hydrophones)
        @test Location(10, 0) == hydrophones[1].location
        @test Position(0.770, -0.065, 1.470) ≈ hydrophones[1].pos
        @test Location(28, 0) == hydrophones[end].location
        @test Position(0.770, -0.065, 1.470) ≈ hydrophones[end].pos
    end

    @testset "tripod" begin
        tripods = read(joinpath(SAMPLES_DIR, "tripod.txt"), Tripod)
        @test 6 == length(tripods)
        @test 7 == tripods[1].id
        @test Position(+587198.628 ,+4016228.693 ,-3433.306) ≈ tripods[1].pos
        @test 13 == tripods[end].id
        @test Position(+587510.740 ,+4016869.160 ,-3451.700) ≈ tripods[end].pos
    end

    @testset "waveform" begin
        waveform = read(joinpath(SAMPLES_DIR, "waveform.txt"), Waveform)
        @test 10 == length(waveform.ids)
        @test waveform.ids[16] == 3
        @test waveform.ids[-15] == 7
    end

    @testset "triggerparameter" begin
        trigger = read(joinpath(SAMPLES_DIR, "acoustics_trigger_parameters.txt"), AcousticsTriggerParameter)
        @test trigger.q == 0.0
        @test trigger.tmax == 0.004
        @test trigger.nmin == 90
    end

    @testset "utilities" begin
        mod = DetectorModule(1, UTMPosition(0, 0, 0), Location(0, 0), 0, PMT[], missing, 0, 0)
        @test hydrophoneenabled(mod)
        @test piezoenabled(mod)
    end
end
