using PlantBiophysics
using Documenter
using Bonito
using DataFrames
using CSV
# We use the ones from PlantBiophysics so it works even with "dev"ed versions:
using PlantMeteo
using PlantSimEngine

include(joinpath(@__DIR__, "bonito_rendering.jl"))
include(joinpath(@__DIR__, "src", "assets", "logo.jl"))
include(joinpath(@__DIR__, "figures", "generate_evaluation_figures.jl"))

@info "Regenerating documentation logo"
PlantBiophysicsLogo.generate_logo()

@info "Regenerating evaluation figures"
EvaluationFigures.generate_evaluation_figures()

DocMeta.setdocmeta!(PlantBiophysics, :DocTestSetup, :(using PlantBiophysics, DataFrames, CSV, PlantMeteo, PlantSimEngine); recursive=true)

home = (
    name="PlantBiophysics.jl",
    text="Simulate how leaves exchange carbon, water, and heat",
    tagline="Combine photosynthesis, stomatal conductance, and energy balance in Julia. " *
            "Fit parameters to measurements and run models from one leaf to whole plants.",
    image="assets/logo.png",
    actions=[
        (text="Run a leaf simulation", link="getting_started/get_started.html", theme="brand"),
        (text="Fit model parameters", link="getting_started/first_fit.html", theme="alt"),
    ],
    features=[
        (
            title="Coupled leaf models",
            details="Calculate photosynthesis, leaf temperature, and heat and water exchanges together.",
            link="simulation/first_simulation.html",
        ),
        (
            title="Fit and evaluate",
            details="Estimate parameters from measurements and compare predicted responses.",
            link="fitting/parameter_fitting.html",
        ),
        (
            title="From leaves to plants",
            details="Apply leaf models to individual organs and their local conditions.",
            link="simulation/mtg_simulation.html",
        ),
        (
            title="Explore uncertainty",
            details="See how uncertain inputs affect simulated results.",
            link="simulation/uncertainty_propagation.html",
        ),
    ],
)

documentation = makedocs(;
    debug=true,
    root=@__DIR__,
    modules=[PlantBiophysics],
    authors="Rémi Vezy <VEZY@users.noreply.github.com> and contributors",
    repo=Documenter.Remotes.GitHub("VEZY", "PlantBiophysics.jl"),
    sitename="PlantBiophysics.jl",
    format=Bonito.DocumenterBonito(;
        repo="github.com/VEZY/PlantBiophysics.jl",
        devbranch="master",
        devurl="dev",
        version=get(ENV, "GITHUB_REF_TYPE", "") == "tag" ? get(ENV, "GITHUB_REF_NAME", "dev") : "dev",
        logo="assets/logo.png",
        home,
        description="Simulate photosynthesis, stomatal conductance, leaf temperature, and exchanges of heat and water in Julia.",
    ),
    pages=[
        "Home" => "index.md",
        "Getting started" => [
            "TL;DR" => "getting_started/get_started.md",
            "Parameter fitting" => "getting_started/first_fit.md",
        ],
        "Design" => "concepts/package_design.md",
        "Variables" => "variables.md",
        "Models" => [
            "Photosynthesis" => "models/photosynthesis.md",
            "Stomatal conductance" => "models/gs.md",
            "Energy balance" => "models/energy_balance.md",
            "Light interception" => "models/light.md",
        ],
        "Evaluation" => "evaluation.md",
        "Micro-climate" => "climate/microclimate.md",
        "Tutorial: Parameter fitting" => "fitting/parameter_fitting.md",
        "Tutorial: Simulation" => [
            "Simple Simulation" => "simulation/first_simulation.md",
            "Several time steps" => "simulation/several_simulation.md",
            "Multi-rate simulation" => "simulation/multirate_simulation.md",
            "Several objects" => "simulation/several_objects_simulation.md",
            "Whole-plant simulation" => "simulation/mtg_simulation.md",
            "Coupling light and physiology" => "simulation/light_coupling.md",
        ],
        "Tutorial: Uncertainty propagation" => "simulation/uncertainty_propagation.md",
        "Extending PlantBiophysics" => [
            "Implement a model" => "extending/implement_a_model.md",
            "Implement a process" => "extending/implement_a_process.md",
        ],
        "API" => "functions.md"
    ]
)

include(joinpath(@__DIR__, "check_static_export.jl"))
finish_static_export()

# Preserve the inventory used by other packages to link to these API docs.
# Bonito renders flat HTML paths, so use the same paths in the inventory.
cd(@__DIR__) do
    context = Documenter.HTMLWriter.HTMLContext(documentation, Documenter.HTML(prettyurls=false))
    Documenter.HTMLWriter.write_inventory(documentation, context)
end

if get(ENV, "PLANTBIOPHYSICS_DOCS_BUILD_ONLY", "false") != "true"
    deploydocs(;
        repo="github.com/VEZY/PlantBiophysics.jl.git",
        devbranch="master",
        push_preview=true,
    )
end
