using Test

@testset "PlantBiophysics documentation" begin
    include(joinpath(@__DIR__, "..", "make.jl"))
    @test isfile(joinpath(@__DIR__, "..", "build", "index.html"))
end
