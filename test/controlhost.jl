using KM3io
import KM3io: CHTag, CHPrefix
using Test

@testset "ControlHost" begin
    @test CHTag([101,99,97,112,50,48,49,50]) == CHTag("ecap2012")
    p = CHPrefix("test", 12)
    @test p.tag == CHTag("test")
    @test 12 == p.length
end
