using PlantBiophysics
using Documenter
using PlantBiophysics
using DataFrames
using CSV
using Plots

DocMeta.setdocmeta!(PlantBiophysics, :DocTestSetup, :(using PlantBiophysics,Plots,DataFrames,CSV); recursive=true)

makedocs(;
    modules=[PlantBiophysics],
    authors="remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo="https://github.com/VEZY/PlantBiophysics.jl/blob/{commit}{path}#L{line}",
    sitename="PlantBiophysics.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://VEZY.github.io/PlantBiophysics.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Getting started" => "get_started.md",
        "Models" => Any[
            "Concepts" => "concepts.md",
            "Photosynthesis" => "photosynthesis.md",
            "Stomatal conductance" => "gs.md",
            "Energy balance" => "energy_balance.md",
            "Light interception" => "light.md"],
        "Functions" => "functions.md"
    ],
)



deploydocs(;
    repo="github.com/VEZY/PlantBiophysics.jl",
)
