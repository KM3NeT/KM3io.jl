using Test
using KM3io
using KM3Aux

@testset "KM3Aux Extension" begin
    # Pull only the LFS objects KM3Aux actually requests, not the full ~6.7 GiB repo.
    ENV["GIT_LFS_SKIP_SMUDGE"] = "1"

    token = get(ENV, "CI_JOB_TOKEN", "")
    if token != ""
        KM3Aux.set_auxiliary_repo("https://gitlab-ci-token:$(token)@git.km3net.de/auxiliary_data/calibration.git")
    end

    hydros = gethydrophones(160, 19466)
    @test length(hydros) >= 28
    @test hydros[1].location == Location(9, -1)
    @test isapprox(hydros[1].pos, Position(-0.570, -0.420, 0.570))

    waveforms = getwaveforms(160, 19466)
    @test 18 == length(keys(waveforms.ids))

    tripods = gettripods(160, 19466)
    @test 5 == length(tripods)

    pmtfile = getpmtfile(160, 19466)
    @test 15624 == length(pmtfile.pmt_data)
end


