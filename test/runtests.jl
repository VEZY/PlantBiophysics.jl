using PlantBiophysics
using Test, Aqua
using Documenter # for doctests

using Dates
using CSV
using DataFrames
using MonteCarloMeasurements
using Random
using Statistics
using MultiScaleTreeGraph

# We use the ones from PlantBiophysics so it works even with "dev"ed versions:
using PlantBiophysics.PlantMeteo
using PlantBiophysics.PlantSimEngine

leaf_status(scene) = only(model_objects(scene; scale=:Leaf)).status

function output_values(sim, variable::Symbol; application=nothing, object=:leaf)
    rows = collect_outputs(sim, object, variable; sink=nothing)
    isnothing(application) || filter!(row -> row.application_id == application, rows)
    return getproperty.(rows, :value)
end

@testset "Testing PlantBiophysics" begin

    Aqua.test_all(
        PlantBiophysics,
        ambiguities=false, # Removing this test as dependencies return ambiguities...
        # Pkg before Julia 1.11 ignores [sources], so Aqua cannot recreate an
        # environment containing the unreleased PlantSimEngine 0.15.
        persistent_tasks=VERSION >= v"1.11",
    )

    @testset "File IO" begin
        include("test-IO.jl")
    end

    @testset "Structures" begin
        include("test-structs.jl")
    end

    @testset "Public API boundaries" begin
        include("test-api-boundaries.jl")
    end

    @testset "Compiled hard dependencies" begin
        include("test-model-dependency.jl")
    end

    @testset "Environment contracts" begin
        include("test-environment-contracts.jl")
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

    @testset "Multi-rate" begin
        include("test-multirate.jl")
    end

    @testset "Empirical evaluation regressions" begin
        include("evaluation/scenarios.jl")
        include("evaluation/helpers.jl")
        include("evaluation/test-global.jl")
        include("evaluation/test-daily.jl")
        include("evaluation/test-schymanski.jl")
    end

    @testset "Fitting" begin
        include("test-fitting.jl")
    end

    @testset "Uncertainty propagation" begin
        include("test-uncertainty-propagation.jl")
    end

    @testset "Doctests" begin
        DocMeta.setdocmeta!(PlantBiophysics, :DocTestSetup, :(using PlantBiophysics, DataFrames, CSV, PlantBiophysics.PlantMeteo, PlantBiophysics.PlantSimEngine); recursive=true)

        # Testing the doctests, i.e. the examples in the docstrings marked with jldoctest:
        doctest(PlantBiophysics; manual=false)
    end

end
