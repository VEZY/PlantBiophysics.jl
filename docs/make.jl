using PlantBiophysics
using Documenter
using DataFrames
using CSV
# We use the ones from PlantBiophysics so it works even with "dev"ed versions:
using PlantMeteo
using PlantSimEngine

function regenerate_evaluation_figures()
    project = joinpath(@__DIR__, "figures")
    script = joinpath(project, "generate_evaluation_figures.jl")
    code = "using Pkg; Pkg.instantiate(); include($(repr(script))); " *
           "EvaluationFigures.generate_evaluation_figures()"
    command = `$(Base.julia_cmd()) --project=$project --startup-file=no -e $code`
    @info "Regenerating evaluation figures"
    run(addenv(command, "GKSwstype" => get(ENV, "GKSwstype", "100")))
    return nothing
end

regenerate_evaluation_figures()

DocMeta.setdocmeta!(PlantBiophysics, :DocTestSetup, :(using PlantBiophysics, DataFrames, CSV, PlantMeteo, PlantSimEngine); recursive=true)

makedocs(;
    modules=[PlantBiophysics],
    authors="remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo=Documenter.Remotes.GitHub("VEZY", "PlantBiophysics.jl"),
    sitename="PlantBiophysics.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://VEZY.github.io/PlantBiophysics.jl",
        assets=String[]
    ),
    pages=[
        "Home" => "index.md",
        "Getting started" => [
            "TL;DR" => "./getting_started/get_started.md",
            "Parameter fitting" => "./getting_started/first_fit.md",
        ],
        "Design" => "./concepts/package_design.md",
        "Variables" => "variables.md",
        "Models" => [
            "Photosynthesis" => "./models/photosynthesis.md",
            "Stomatal conductance" => "./models/gs.md",
            "Energy balance" => "./models/energy_balance.md",
            "Light interception" => "./models/light.md",
        ],
        "Evaluation" => "evaluation.md",
        "Micro-climate" => "./climate/microclimate.md",
        "Tutorial: Parameter fitting" => "./fitting/parameter_fitting.md",
        "Tutorial: Simulation" => [
            "Simple Simulation" => "./simulation/first_simulation.md",
            "Multi-rate simulation" => "./simulation/multirate_simulation.md",
            "Multiple objects and plants" => "./simulation/mtg_simulation.md",
        ],
        "Tutorial: Uncertainty propagation" => "./simulation/uncertainty_propagation.md",
        "Extending PlantBiophysics" => [
            "Implement a model" => "./extending/implement_a_model.md",
            "Implement a process" => "./extending/implement_a_process.md",
        ],
        "API" => "functions.md"
    ]
)



deploydocs(;
    repo="github.com/VEZY/PlantBiophysics.jl.git"
)
