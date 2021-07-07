using Base:Float64
using PlantBiophysics
using OrderedCollections
using MutableNamedTuples
using Test
using DataFrames

@testset "File IO" begin
    include("IO.jl")
end

@testset "Structures" begin
    include("structs.jl")
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
