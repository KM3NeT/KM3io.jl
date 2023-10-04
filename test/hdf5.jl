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
