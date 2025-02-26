# Simulation on a plant (MTG)

```@setup usepkg
using PlantBiophysics, PlantSimEngine, PlantMeteo, MultiScaleTreeGraph, PlantGeom
using CairoMakie, Dates

mtg = read_opf(joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf"))

weather = read_weather(
    joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv"),
    :temperature => :T,
    :relativeHumidity => (x -> x ./ 100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)

models = read_model(joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "models", "plant_coffee.yml"));

transform!(
    mtg,
    :Ra_PAR_f => (x -> fill(x, length(weather))) => :Ra_PAR_f,
    :sky_fraction => (x -> fill(x, length(weather))) => :sky_fraction,
    [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x .+ y) => :Ra_SW_f,
    (x -> 0.3) => :d,
    ignore_nothing = true
)

out = run!(mtg, models, weather, tracked_outputs=Dict{String,Any}("Leaf" => (:Tₗ,)))
outputs_leaves = outputs(out)["Leaf"]
for ts in eachindex(outputs_leaves[:node])
    for node in outputs_leaves[:node][ts]
        node[:Tₗ] = outputs_leaves[:Tₗ][ts]
    end
end
```

## Multi-scale Tree Graph

The Multi-scale Tree Graph, or MTG for short is a data structure that helps represent a plant topology, and optionally its geometry.

The OPF is a file format that stores an MTG with geometry onto the disk. Let's read an example OPF using `read_opf()`, a function from the `PlantGeom` package:

```@example usepkg
using PlantGeom
mtg = read_opf(joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf"))
```

The result is an MTG defining the plant at several scales using a tree graph. You can read the introduction to the MTG from [MultiScaleTreeGraph.jl](https://vezy.github.io/MultiScaleTreeGraph.jl/stable/the_mtg/mtg_concept/)'s documentation if you want to understand how it works.

Now let's import the weather data:

```@example usepkg
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

weather = read_weather(
    joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv"),
    :temperature => :T,
    :relativeHumidity => (x -> x ./ 100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)
```

And read the models associated to the MTG from a YAML file:

```@example usepkg
file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "models", "plant_coffee.yml")
models = read_model(file)
```

Let's check which variables we need to provide for our model configuration:

```@example usepkg
to_initialize(models, mtg)
```

OK, only the `"Leaf"` component must be initialized before computation for the coupled energy balance, with the characteristic dimension of the object `d`.

But we also know that the `Translucent` model reads some variables from the MTG nodes directly: the absorbed shortwave radiation flux `Ra_SW_f`, the visible sky fraction seen by the object `sky_fraction`, and the photosynthetically active absorbed radiation flux `Ra_PAR_f`. We are in luck, we used [Archimed-ϕ](https://archimed-platform.github.io/archimed-phys-user-doc/) to compute the radiation interception of each organ in the example coffee plant we are using. So the only thing we need to do is to transform the variables given by Archimed-ϕ in each node to compute the ones we need. We use `transform!` from `MultiScaleTreeGraph.jl` to traverse the MTG and compute the right variable for each node:

```@example usepkg
using MultiScaleTreeGraph

transform!(
    mtg,
    :Ra_PAR_f => (x -> fill(x, length(weather))) => :Ra_PAR_f,
    :sky_fraction => (x -> fill(x, length(weather))) => :sky_fraction,
    [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x .+ y) => :Ra_SW_f,
    (x -> 0.3) => :d,
    ignore_nothing = true
)
```

The design of `MultiScaleTreeGraph.transform!` is very close to the one from `DataFrames`. It helps us compute new variables (or attributes) from others, modify their units or rename them. Here we compute a value for each time-step by repeating the values of `Ra_PAR_f` and `sky_fraction` 3 times, and compute `Ra_SW_f` from the sum of `Ra_PAR_f` (absorbed radiation flux in the PAR) and `Ra_NIR_f` (...in the NIR). We also put a single constant value for `d`: 0.3 m.

Now let's choose the outputs we want to save. Here we choose to only output the leaf temperature `Tₗ`:

```@example usepkg
vars=Dict{String,Any}("Leaf" => (:Tₗ,))
```

Now we can run a simulation using `run!` from `PlantSimEngine`:

```@example usepkg
outs = run!(mtg, models, weather, tracked_outputs=vars);
nothing # hide
```

We can now extract the outputs from the simulation and store them in the MTG:

```@example usepkg
outputs_leaves = outputs(outs)["Leaf"]
for ts in eachindex(outputs_leaves[:node])
    for node in outputs_leaves[:node][ts]
        node[:Tₗ] = outputs_leaves[:Tₗ][ts]
    end
end
```

And finally, we can visualize the outputs in 3D using PlantGeom's `viz` function:

```@example usepkg
f, ax, p = viz(mtg, color = :Tₗ, index = 2)
colorbar(f[1, 2], p)
f
```

Note that we use the `index` keyword argument to select the time-step we want to visualize.