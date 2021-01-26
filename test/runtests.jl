using PlantBiophysics
using Test

@testset "Temperature dependence" begin
    include("temp-dependence.jl")
end


@testset "Stomatal conductance" begin
    include("gs.jl")
end
