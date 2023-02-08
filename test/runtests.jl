using Test

@testset "KM3io.jl" begin
    include("root.jl")
    include("tools.jl")
    include("hardware.jl")
    include("acoustics.jl")
end
