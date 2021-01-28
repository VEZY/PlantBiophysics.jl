using PlantBiophysics
using OrderedCollections
using Test

@testset "File IO" begin
    include("IO.jl")
end

@testset "Temperature dependence" begin
    include("temp-dependence.jl")
end


@testset "Stomatal conductance" begin
    include("gs.jl")
end
