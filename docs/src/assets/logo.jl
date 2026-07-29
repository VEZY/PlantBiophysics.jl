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
const DEFAULT_OUTPUT = joinpath(@__DIR__, "logo.png")
const MIN_OUTPUT_PIXELS = 384

function save_cropped_logo(output, figure; padding=20)
    image = colorbuffer(figure)
    foreground = findall(
        pixel -> CairoMakie.Makie.alpha(pixel) > 0,
        image,
    )
    isempty(foreground) && error("The rendered logo contains no visible pixels")

    row_min, row_max = extrema(index -> index[1], foreground)
    column_min, column_max = extrema(index -> index[2], foreground)
    row_min = max(1, row_min - padding)
    row_max = min(size(image, 1), row_max + padding)
    column_min = max(1, column_min - padding)
    column_max = min(size(image, 2), column_max + padding)

    # Keep a square logo while centering the visible plant within it.
    side = max(row_max - row_min + 1, column_max - column_min + 1)
    row_center = (row_min + row_max) ÷ 2
    column_center = (column_min + column_max) ÷ 2
    row_start = clamp(row_center - side ÷ 2, 1, size(image, 1) - side + 1)
    column_start = clamp(
        column_center - side ÷ 2,
        1,
        size(image, 2) - side + 1,
    )
    cropped = image[
        row_start:(row_start + side - 1),
        column_start:(column_start + side - 1),
    ]
    minimum(size(cropped)) >= MIN_OUTPUT_PIXELS || error(
        "The rendered logo must be at least $(MIN_OUTPUT_PIXELS) × " *
        "$(MIN_OUTPUT_PIXELS) pixels for high-density documentation displays",
    )

    mkpath(dirname(output))
    save(output, cropped)
    return output
end

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

    # A near top-down orthographic view reproduces the original logo's dense
    # canopy composition. PNG is intentional here: CairoMakie's SVG export of
    # a large 3D mesh relies on thousands of nested filters and masks that are
    # not rendered consistently when Documenter scales the image as a logo.
    figure = Figure(
        size=(600, 600),
        figure_padding=0,
        backgroundcolor=:transparent,
    )
    axis = Axis3(
        figure[1, 1];
        # The logo is viewed along the vertical axis. A cubic plotting box
        # therefore uses the available square instead of shrinking the canopy
        # to accommodate the plant's height.
        aspect=:equal,
        backgroundcolor=:transparent,
        azimuth=1.275π,
        elevation=π / 2 - 0.01,
        perspectiveness=0.0,
        protrusions=0,
        viewmode=:stretch,
    )
    plantviz!(axis, mtg; color=:Tₗ_1)
    hidedecorations!(axis)
    hidespines!(axis)

    return save_cropped_logo(output, figure)
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    generate_logo()
end

end
