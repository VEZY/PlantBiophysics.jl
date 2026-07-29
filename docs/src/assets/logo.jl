module PlantBiophysicsLogo

# From the repository root:
#   julia --project=docs docs/src/assets/logo.jl

using CairoMakie
using Dates
using MultiScaleTreeGraph
using PlantBiophysics
using PlantGeom
using PlantMeteo
using PlantSimEngine

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const DEFAULT_OUTPUT = joinpath(@__DIR__, "logo.svg")

"""
    generate_logo(; output=DEFAULT_OUTPUT)

Regenerate the PlantBiophysics logo from the bundled coffee-plant geometry,
model configuration, and the first meteorological timestep used by the
original logo.
"""
function generate_logo(; output=DEFAULT_OUTPUT)
    mtg = read_opf(
        joinpath(ROOT, "test", "inputs", "scene", "opf", "coffee.opf"),
    )
    models = read_model(
        joinpath(ROOT, "test", "inputs", "models", "plant_coffee.yml"),
    )

    # These conditions are the first row of the meteorological fixture used by
    # the original script. Keeping them here avoids depending on another
    # package's test data.
    meteo = Atmosphere(
        T=25.0,
        Rh=0.60,
        Wind=1.0,
        Cₐ=380.0,
        duration=Minute(30),
    )

    # Translucent only copied these values from the MTG in the legacy runner.
    # Initializing them directly lets the current CompositeModel API simulate
    # exactly the first timestep that was used to color the original logo.
    leaf_models = filter(
        model -> process(model) != :light_interception,
        models[:Leaf],
    )
    applications = Tuple(
        ModelSpec(model; name=process(model)) |>
        AppliesTo(Many(scale=:Leaf))
        for model in leaf_models
    )
    scene = CompositeModel(
        mtg;
        applications=applications,
        environment=meteo,
        status=node -> Symbol(symbol(node)) == :Leaf ? Status(
            Ra_SW_f=node[:Ra_PAR_f] + node[:Ra_NIR_f],
            aPPFD=node[:Ra_PAR_f] * 4.57,
            sky_fraction=node[:sky_fraction],
            d=0.3,
        ) : nothing,
    )

    run!(scene)

    # CompositeModel keeps simulation state on model objects. PlantGeom colors
    # the MTG, so copy the first-timestep leaf temperatures back to its nodes.
    for leaf in model_objects(scene; scale=:Leaf)
        get_node(mtg, leaf.id.value)[:Tₗ_1] = leaf.status.Tₗ
    end

    figure = Figure(size=(600, 450), backgroundcolor=:transparent)
    axis = Axis3(
        figure[1, 1];
        aspect=:data,
        backgroundcolor=:transparent,
    )
    plantviz!(axis, mtg; color=:Tₗ_1)
    hidedecorations!(axis)
    hidespines!(axis)

    mkpath(dirname(output))
    save(output, figure)
    return output
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    generate_logo()
end

end
