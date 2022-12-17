using PlantBiophysics
using Test, Aqua

using OrderedCollections
using Dates
using DataFrames
using MultiScaleTreeGraph
using PlantBiophysics

# We use the ones from PlantBiophysics so it works even with "dev"ed versions:
using PlantBiophysics.PlantMeteo
using PlantBiophysics.PlantSimEngine

Aqua.test_all(
    PlantBiophysics,
    ambiguities=false # Removing this test as dependencies return ambiguities...
)

@testset "File IO" begin
    include("test-IO.jl")
end

@testset "Structures" begin
    include("test-structs.jl")
end

@testset "Temperature dependence" begin
    include("test-temp-dependence.jl")
end

@testset "Light interception" begin
    include("test-beer.jl")
end

@testset "Stomatal conductance" begin
    include("test-gs.jl")
end

@testset "Energy balance" begin
    include("test-energy_balance.jl")
end

# @testset "MTG compatibility" begin
#     include("test-mtg.jl")
# end

@testset "Fitting" begin
    include("test-fitting.jl")
end
