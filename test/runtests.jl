using PlantBiophysics
using OrderedCollections
using MutableNamedTuples
using Test
using Dates
using DataFrames
using MultiScaleTreeGraph, PlantGeom

@testset "File IO" begin
    include("IO.jl")
end

@testset "Atmosphere" begin
    include("atmosphere.jl")
end

@testset "Structures" begin
    include("structs.jl")
end

@testset "Initialisations" begin
    include("initialisations.jl")
end

@testset "Temperature dependence" begin
    include("temp-dependence.jl")
end

@testset "Stomatal conductance" begin
    include("gs.jl")
end

@testset "Energy balance" begin
    include("energy_balance.jl")
end

@testset "MTG compatibility" begin
    include("test-mtg.jl")
end

@testset "Fitting" begin
    include("test-fitting.jl")
end
