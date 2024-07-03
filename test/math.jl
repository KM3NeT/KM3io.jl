import KM3io: slerp
using Test

@testset "slerp()" begin
    q1 = [1.0, 0.0]
    q2 = [0.0, 1.0]
    @test q1 ≈ slerp(q1, q2, 0)
    @test q2 ≈ slerp(q1, q2, 1)
    @test [0.9510565162951538, 0.30901699437494745] ≈ slerp(q1, q2, 0.2)
    @test [0.70710678, 0.70710678] ≈ slerp(q1, q2, 0.5)
    @test [0.45399049973954686, 0.8910065241883678] ≈ slerp(q1, q2, 0.7)

    # should normalise internally
    q1 = [0.4, 0.0]
    q2 = [0.0, 0.9]
    @test [1.0, 0.0] ≈ slerp(q1, q2, 0; normalized=false)
    @test [0.0, 1.0] ≈ slerp(q1, q2, 1; normalized=false)
    @test [0.9510565162951538, 0.30901699437494745] ≈ slerp(q1, q2, 0.2; normalized=false)
    @test [0.70710678, 0.70710678] ≈ slerp(q1, q2, 0.5; normalized=false)
    @test [0.45399049973954686, 0.8910065241883678] ≈ slerp(q1, q2, 0.7; normalized=false)

    q1 = [1.0, 0.0, 0.0]
    q2 = [0.0, 0.0, 1.0]
    @test q1 ≈ slerp(q1, q2, 0)
    @test q2 ≈ slerp(q1, q2, 1)
    @test [0.9510565162951538, 0.0, 0.30901699437494745] ≈ slerp(q1, q2, 0.2)
    @test [0.70710678, 0.0, 0.70710678] ≈ slerp(q1, q2, 0.5)
    @test [0.45399049973954686, 0.0, 0.8910065241883678] ≈ slerp(q1, q2, 0.7)
end
