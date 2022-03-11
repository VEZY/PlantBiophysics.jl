using PlantBiophysics
using Documenter
using PlantBiophysics
using DataFrames
using CSV
using Plots

DocMeta.setdocmeta!(PlantBiophysics, :DocTestSetup, :(using PlantBiophysics, Plots, DataFrames, CSV); recursive = true)

makedocs(;
    modules = [PlantBiophysics],
    authors = "remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo = "https://github.com/VEZY/PlantBiophysics.jl/blob/{commit}{path}#L{line}",
    sitename = "PlantBiophysics.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://VEZY.github.io/PlantBiophysics.jl",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md",
        "Getting started" => [
            "TL;DR" => "./getting_started/get_started.md",
            "Parameter fitting" => "./getting_started/first_fit.md",
        ],
        "Design" => "./concepts/package_design.md",
        "Components and methods" => Any[
            "LeafModels"=>"./components/leafmodels.md",
            "ComponentModels"=>"./components/componentmodels.md",
            "Implement a component model"=>"./components/implement_a_component.md",
        ],
        "Models for LeafModels" => Any[
            "Photosynthesis"=>"./models/photosynthesis.md",
            "Stomatal conductance"=>"./models/gs.md",
            "Energy balance"=>"./models/energy_balance.md",
            "Light interception"=>"./models/light.md",
            "Implement a model"=>"./models/implement_a_model.md",
        ],
        "Micro-climate" => "./climate/microclimate.md",
        "Tutorial: Parameter fitting" => "./fitting/parameter_fitting.md",
        "Tutorial: Simulation" => [
            "Simple Simulation" => "./simulation/first_simulation.md",
            "Several time steps" => "./simulation/several_simulation.md",
            "Several objects" => "./simulation/several_objects_simulation.md",
            "Whole-plant simulation" => "./simulation/mtg_simulation.md",
        ],
        "Tutorial: Uncertainty propagation" => "./simulation/uncertainty_propagation.md",
        "API" => "functions.md"
    ]
)



deploydocs(;
    repo = "github.com/VEZY/PlantBiophysics.jl.git"
)
