using PlantBiophysics
using Documenter
using PlantBiophysics
using DataFrames
using CSV
using Plots

DocMeta.setdocmeta!(PlantBiophysics, :DocTestSetup, :(using PlantBiophysics,Plots,DataFrames,CSV); recursive = true)

makedocs(;
    modules = [PlantBiophysics],
    authors = "remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo = "https://github.com/VEZY/PlantBiophysics.jl/blob/{commit}{path}#L{line}",
    sitename = "PlantBiophysics.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://VEZY.github.io/PlantBiophysics.jl",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
        "Getting started" => [
            "TL;DR" => "./getting_started/get_started.md",
            "First simulation" => "./getting_started/first_simulation.md",
            "Several time steps" => "./getting_started/several_simulation.md",
            "Several objects" => "./getting_started/several_objects_simulation.md",
            "Overall concepts" => "./getting_started/package_design.md",
            ],
        "Models" => Any[
            "Photosynthesis" => "photosynthesis.md",
            "Stomatal conductance" => "gs.md",
            "Energy balance" => "energy_balance.md",
            "Light interception" => "light.md"
            ],
        "Details" => Any[
            "Package design" => "concepts.md",
            "Implement a model" => "implement_a_model.md",
            "Uncertainty propagation" => "uncertainty_propagation.md",
        ],
        "API" => "functions.md"
    ],
)



deploydocs(;
    repo = "github.com/VEZY/PlantBiophysics.jl.git",
)
