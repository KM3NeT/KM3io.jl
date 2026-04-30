using KM3io
using HDF5
using Test

struct Bar
    a::Int32
    b::Float64
end

@testset "HDF5" begin
    fname = tempname()
    bars = [Bar(x, x*2.1) for x ∈ 1:100]

    f = H5File(fname, "w")
    d = create_dataset(f, "bars", Bar; cache_size=3)
    for bar ∈ bars
        push!(d, bar)
    end
    close(f)

    f = h5open(fname, "r")
    @test KM3io.version == VersionNumber(attrs(f)["KM3io.jl"])
    @test bars == reinterpret(Bar, f["bars"][:])
    close(f)

    f = H5File(fname, "cw")
    d = create_dataset(f, "bars_flushed", Bar; cache_size=1000)
    for bar ∈ bars
        push!(d, bar)
    end
    flush(d)

    _f = h5open(fname, "r")
    @test bars == reinterpret(Bar, _f["bars"][:])
    @test "Bar" == attrs(_f["bars"])["struct_name"]
    close(_f)


    write(f, "directly_written_bars", bars)
    @test bars == reinterpret(Bar, f["directly_written_bars"][:])

    addmeta(d, Bar(1, 2.3))
    @test read_attribute(d, "a") == 1
    @test read_attribute(d, "b") == 2.3

    d2 = create_dataset(f, "foo", Int32; cache_size=1000)
    addmeta(d2.dset, Bar(3, 4.5))
    @test read_attribute(d2, "a") == 3
    @test read_attribute(d2, "b") == 4.5

    addmeta(f, Bar(6, 7.8))
    @test read_attribute(f, "a") == 6
    @test read_attribute(f, "b") == 7.8

    close(f)
end

@testset "H5uDSTFile" begin
    @testset "round-trip with primitive and NamedTuple columns" begin
        fname = tempname()
        f = H5uDSTFile(fname, "w"; parameters=[
            (:bdt_score, Float64, "BDT score test"),
            :crkv_hits,
            :coords,
        ])
        @test !isempty(keys(f))
        @test description(f, :bdt_score) == "BDT score test"
        @test occursin("Cherenkov", description(f, :crkv_hits))   # auto from registry
        @test description(f, :coords) isa AbstractString

        for i in 1:5
            push!(f, (
                bdt_score = 0.1 * i,
                crkv_hits = (nhits=Int32(i), nhits_20m=Int32(2i), nhits_50m=Int32(3i),
                             nhits_100m=Int32(4i), nhits_200m=Int32(5i),
                             sumtot=10.0i, closest=0.5i, furthest=100.0i),
                coords = (mjd=58849.0+i, nu_ra=0.1i, nu_dec=0.2i,
                          trackfit_ra=0.3i, trackfit_dec=0.4i,
                          showerfit_ra=0.5i, showerfit_dec=0.6i),
            ))
        end
        close(f)

        g = H5uDSTFile(fname)
        @test sort(keys(g)) == sort([:bdt_score, :crkv_hits, :coords])
        @test length(g) == 5
        @test isapprox(g[:bdt_score], [0.1, 0.2, 0.3, 0.4, 0.5])
        chk = g[:crkv_hits]
        @test length(chk) == 5
        @test chk[1].nhits == 1
        @test chk[5].sumtot == 50.0
        @test eltype(chk) == UDST_CHERENKOV_HITS
        @test g[:coords][3].mjd == 58852.0
        @test description(g, :bdt_score) == "BDT score test"
        @test occursin("Cherenkov", description(g, :crkv_hits))
        @test haskey(metadata(g, :crkv_hits), "description")
        @test validate_lengths(g)
        close(g)
    end

    @testset "field-order independence in NamedTuple values" begin
        fname = tempname()
        f = H5uDSTFile(fname, "w"; parameters=[:crkv_hits])
        # Push with fields in an arbitrary order:
        push!(f, (crkv_hits = (
            sumtot = 99.0, closest = 1.0, furthest = 50.0,
            nhits = Int32(7),
            nhits_200m = Int32(11), nhits_100m = Int32(8),
            nhits_50m = Int32(5), nhits_20m = Int32(2),
        ),))
        close(f)
        g = H5uDSTFile(fname)
        v = g[:crkv_hits][1]
        @test v.nhits == 7
        @test v.nhits_20m == 2
        @test v.sumtot == 99.0
        @test v.furthest == 50.0
        close(g)
    end

    @testset "imperative registration with type override" begin
        fname = tempname()
        f = H5uDSTFile(fname, "w")
        register!(f, :bdt_score, Float32; description="BDT v1")
        register!(f, :crkv_hits)   # type from registry
        @test description(f, :bdt_score) == "BDT v1"
        push!(f, (bdt_score = Float32(0.42),
                  crkv_hits = (nhits=Int32(1), nhits_20m=Int32(0), nhits_50m=Int32(0),
                               nhits_100m=Int32(0), nhits_200m=Int32(0),
                               sumtot=0.0, closest=0.0, furthest=0.0)))
        close(f)
        g = H5uDSTFile(fname)
        @test g[:bdt_score] == Float32[0.42]
        close(g)
    end

    @testset "strict push! enforces full parameter coverage" begin
        fname = tempname()
        f = H5uDSTFile(fname, "w"; parameters=[(:a, Int32), (:b, Float64)])
        @test_throws ErrorException push!(f, (a = Int32(1),))            # missing :b
        @test_throws ErrorException push!(f, (a = Int32(1), b = 2.0, c = 3.0))  # unknown :c
        # OK case
        push!(f, (a = Int32(1), b = 2.0))
        close(f)
        g = H5uDSTFile(fname)
        @test g[:a] == Int32[1]
        @test g[:b] == [2.0]
        close(g)
    end

    @testset "partial push! for backfilling new columns (rewind use case)" begin
        fname = tempname()
        f = H5uDSTFile(fname, "w"; parameters=[(:a, Int32), (:b, Float64)])
        for i in 1:5
            push!(f, (a = Int32(i), b = Float64(i)))
        end
        close(f)

        # Reopen, register a new column, backfill via partial push.
        f = H5uDSTFile(fname, "r+")
        register!(f, :c, Float32; description="new column")
        @test length(f) == 5
        @test !validate_lengths(f)            # c has 0 elements vs 5

        for i in 1:5
            push!(f, (c = Float32(10i),); strict=false)
        end
        @test validate_lengths(f)
        # Partial push with unknown key still errors:
        @test_throws ErrorException push!(f, (nonexistent = 1.0,); strict=false)
        close(f)

        g = H5uDSTFile(fname)
        @test g[:a] == Int32[1, 2, 3, 4, 5]
        @test g[:b] == Float64[1, 2, 3, 4, 5]
        @test g[:c] == Float32[10, 20, 30, 40, 50]
        close(g)
    end

    @testset "append events to existing file" begin
        fname = tempname()
        f = H5uDSTFile(fname, "w"; parameters=[(:x, Float64)])
        for i in 1:3
            push!(f, (x = Float64(i),))
        end
        close(f)

        f = H5uDSTFile(fname, "r+")
        @test length(f) == 3
        @test description(f, :x) === missing
        for i in 4:6
            push!(f, (x = Float64(i),))
        end
        close(f)

        g = H5uDSTFile(fname)
        @test g[:x] == Float64[1, 2, 3, 4, 5, 6]
        close(g)
    end

    @testset "validate against parameter sets" begin
        fname = tempname()
        f = H5uDSTFile(fname, "w"; parameters=[:coords])
        @test validate(f, UDST_ASTRO)                                # {:coords}
        @test !validate(f, UDST_RECO_TRACKS)                         # has none
        @test validate(f, [:coords])
        @test validate(f, Set([:coords]))
        @test validate(f, (:coords,))
        @test validate(f, (coords = nothing,))
        @test !validate(f, [:coords, :bdt_score])
        close(f)
    end

    @testset "isbitstype enforcement" begin
        fname = tempname()
        f = H5uDSTFile(fname, "w")
        @test_throws ErrorException register!(f, :bad, String)       # String is not isbits
        @test_throws ErrorException register!(f, :bad2, Vector{Int})
        close(f)
    end

    @testset "read-only mode rejects writes" begin
        fname = tempname()
        f = H5uDSTFile(fname, "w"; parameters=[(:x, Float64)])
        push!(f, (x = 1.0,))
        close(f)

        g = H5uDSTFile(fname)
        @test_throws ErrorException register!(g, :y, Float64)
        @test_throws ErrorException push!(g, (x = 2.0,))
        close(g)
    end

    @testset "custom group path" begin
        fname = tempname()
        f = H5uDSTFile(fname, "w"; group="/my/sub/path", parameters=[(:x, Int32)])
        push!(f, (x = Int32(7),))
        close(f)

        # Default group is empty -> no params discovered.
        g = H5uDSTFile(fname)
        @test isempty(keys(g))
        close(g)

        # Pointing at the right group recovers the data.
        h = H5uDSTFile(fname; group="/my/sub/path")
        @test keys(h) == [:x]
        @test h[:x] == Int32[7]
        close(h)
    end

    @testset "default-type lookup error for unknown branch names" begin
        fname = tempname()
        f = H5uDSTFile(fname, "w")
        @test_throws ErrorException register!(f, :totally_unknown_branch_name)
        close(f)
    end
end
