using KM3io
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


@testset "quaternions and compasses" begin
    c = Compass(1.0, 1.0, 1.0)
    q = Quaternion(c)
    @test 0.7860666291368439 == q.q0
    @test -0.16751879124639693 == q.qx
    @test 0.5709414713577319 == q.qy
    @test -0.16751879124639693 == q.qz
    @test c ≈ Compass(q)
end
