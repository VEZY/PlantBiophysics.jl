# This tests comes from https://github.com/MasonProtter/MutableNamedTuples.jl/blob/master/test/runtests.jl
@testset "Testing Status" begin
    mnt = Status(a=1, b="hi")
    @test mnt isa Status
    mnt.a = 2

    @test mnt.a == 2
    @test NamedTuple(mnt) == (; a=2, b="hi")
    @test collect(mnt) == [2; "hi"]
    @test length(mnt) == 2
    @test mnt[1] == 2
    @test mnt[2] == "hi"
    @test mnt[:a] == 2
    @test mnt[:b] == "hi"

    mnt2 = Status{(:a, :b)}((2, "hi"))
    @test NamedTuple(mnt2) == NamedTuple(mnt)
end