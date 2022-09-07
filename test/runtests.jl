using PlantBiophysics
using OrderedCollections
using MutableNamedTuples
using Test
using Dates
using DataFrames
using MultiScaleTreeGraph, PlantGeom

@testset "File IO" begin
    include("test-IO.jl")
end

@testset "Atmosphere" begin
    include("test-atmosphere.jl")
end

@testset "Structures" begin
    include("test-structs.jl")
end

@testset "Initialisations" begin
    include("test-initialisations.jl")
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

@testset "MTG compatibility" begin
    include("test-mtg.jl")
end

@testset "Fitting" begin
    include("test-fitting.jl")
end
