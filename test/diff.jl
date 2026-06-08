using Test
using KM3io
using KM3NeTTestData

@testset "compare" begin
    detx = Detector(datapath("detx", "KM3NeT_00000133_20221025.detx"))
    datx = Detector(datapath("datx", "KM3NeT_00000133_20221025.datx"))

    firstoptical(d) = first(Iterators.filter(isopticalmodule, d))

    @testset "identity" begin
        d = compare(detx, detx)
        @test isidentical(d)
        @test isempty(d)
        @test ndiffs(d) == 0
    end

    @testset "detx vs datx" begin
        # PMT positions/t0 are bit-identical; PMT directions agree to ~4e-6
        # (the detx stores directions at lower precision than the binary datx)
        @test isidentical(compare(detx, datx; atol=1e-5))
        # without any tolerance the sub-micron geometry differences surface
        @test !isidentical(compare(detx, datx; atol=0.0, rtol=0.0))
    end

    @testset "perturbed module t0" begin
        m = firstoptical(detx)
        m2 = DetectorModule(m.id, m.pos, m.location, m.n_pmts, m.pmts, m.q, m.status, m.t₀ + 7.0)
        d = compare(m, m2)
        @test !isidentical(d)
        @test ndiffs(d) == 1
        @test d.changes[1].field == :t₀
        @test d.changes[1].delta ≈ 7.0
    end

    @testset "perturbed PMT position" begin
        m = firstoptical(detx)
        p = first(m.pmts)
        p2 = PMT(p.id, p.pos + Position(0.0, 0.0, 0.01), p.dir, p.t₀, p.status)
        pmts2 = copy(m.pmts)
        pmts2[1] = p2
        m2 = DetectorModule(m.id, m.pos, m.location, m.n_pmts, pmts2, m.q, m.status, m.t₀)
        d = compare(m, m2)
        @test !isidentical(d)
        @test length(d.children) == 1
        pmtdiff = d.children[1]
        @test pmtdiff.changes[1].field == :pos
        @test pmtdiff.changes[1].delta ≈ 0.01
    end

    @testset "missing element" begin
        ms = collect(Iterators.take(Iterators.filter(isopticalmodule, detx), 3))
        d = compare(ms, ms[1:2])  # the third module exists only on the left
        @test !isidentical(d)
        @test length(d.onlyleft) == 1
        @test isempty(d.onlyright)
        @test ndiffs(d) == 1
    end

    @testset "NaN handling" begin
        p = first(firstoptical(detx).pmts)
        pnan = PMT(p.id, p.pos, p.dir, NaN, p.status)
        @test isidentical(compare(pnan, pnan; nanequal=true))
        @test !isidentical(compare(pnan, pnan; nanequal=false))
        pfin = PMT(p.id, p.pos, p.dir, 5.0, p.status)
        @test !isidentical(compare(pnan, pfin))
    end

    @testset "type and numeric leaves" begin
        @test isidentical(compare(1, 1))
        @test !isidentical(compare(1, 2))
        @test !isidentical(compare(1, 1.5))  # int vs float compared by value
        d = compare(1, "a")                  # genuine type mismatch
        @test !isidentical(d)
        @test d.changes[1].kind == :type
    end

    @testset "generic struct path (Evt)" begin
        f = ROOTFile(datapath("offline", "numucc.root"))
        evt = f.offline[1]
        @test isidentical(compare(evt, evt))
    end

    @testset "display" begin
        m = firstoptical(detx)
        m2 = DetectorModule(m.id, m.pos, m.location, m.n_pmts, m.pmts, m.q, m.status, m.t₀ + 7.0)
        s = sprint(show, MIME("text/plain"), compare(m, m2))
        @test occursin("t₀", s)
        @test occursin("Delta", s)
        s0 = sprint(show, MIME("text/plain"), compare(m, m))
        @test occursin("no differences", s0)
    end
end
