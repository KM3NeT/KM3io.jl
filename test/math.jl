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

@testset "Quaternion Hamilton product and conjugate" begin
    q_id = Quaternion(1.0, 0.0, 0.0, 0.0)

    # identity ⊗ q == q
    q = Quaternion(0.5, 0.5, 0.5, 0.5)
    @test q_id ⊗ q ≈ q
    @test q ⊗ q_id ≈ q

    # conjugate of identity
    @test conj(q_id) == Quaternion(1.0, 0.0, 0.0, 0.0)

    # q ⊗ conj(q) == identity for unit quaternion
    q_unit = Quaternion(0.5, 0.5, 0.5, 0.5)  # already unit: 0.5²*4 = 1
    prod = q_unit ⊗ conj(q_unit)
    @test prod.q0 ≈ 1.0 atol=1e-15
    @test prod.qx ≈ 0.0 atol=1e-15
    @test prod.qy ≈ 0.0 atol=1e-15
    @test prod.qz ≈ 0.0 atol=1e-15

    # 90° rotation around z: rotating (1,0,0) should give (0,1,0)
    angle = π / 2
    q_z90 = Quaternion(cos(angle/2), 0.0, 0.0, sin(angle/2))
    p = q_z90 ⊗ Quaternion(0.0, 1.0, 0.0, 0.0) ⊗ conj(q_z90)
    @test p.qx ≈ 0.0 atol=1e-15
    @test p.qy ≈ 1.0 atol=1e-15
    @test p.qz ≈ 0.0 atol=1e-15
end
