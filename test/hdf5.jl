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

    f = H5File(fname)
    d = create_dataset(f, "bars", Bar; cache_size=3)
    for bar ∈ bars
        push!(d, bar)
    end
    close(f)

    f = h5open(fname, "r")
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

    close(f)
end
