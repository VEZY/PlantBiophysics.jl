# Simulation on a plant (MTG)

```@setup usepkg
using PlantBiophysics, MultiScaleTreeGraph, PlantGeom, CairoMakie, Dates

mtg = read_opf(joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf"))
weather = read_weather(
    joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "meteo.csv"),
    :temperature => :T,
    :relativeHumidity => (x -> x ./ 100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)
models = read_model(joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "models", "plant_coffee.yml"))

transform!(
    mtg,
    [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y) => :Rₛ,
    :Ra_PAR_f => (x -> x * 4.57) => :PPFD,
    (x -> 0.3) => :d,
    ignore_nothing = true
)

energy_balance!(mtg, models, weather)

transform!(
    mtg,
    :Tₗ => (x -> x[1]) => :Tₗ_1,
    ignore_nothing = true
)
```

## Multiscale Tree Graph

The Multiscale Tree Graph, or MTG for short is a data structure that help represent a plant topology, and optionally its geometry.

The OPF is a file format that helps store an MTG with geometry onto the disk. Let's read an example OPF using `read_opf()`, a function from the `PlantGeom` package:

```@example usepkg
using PlantGeom
mtg = read_opf(joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf"))
```

The result is an MTG defining the plant at several scales using a tree graph. You can read the introduction to the MTG from [MultiScaleTreeGraph.jl](https://vezy.github.io/MultiScaleTreeGraph.jl/stable/the_mtg/mtg_concept/)'s documentation if you want to understand how it works.

Now let's import the weather data:

```@example usepkg
using PlantBiophysics

weather = read_weather(
    joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "meteo.csv"),
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
to_initialise(models)
```

OK, only the `"Leaf"` component must be initialised before computation, with Rₛ (the shortwave radiation), sky_fraction (the visible sky fraction seen by the object), d (the characteristic dimension of the object) and PPFD (the Photosynthetically active Photon Flux Density). We are in luck, we used [Archimed-ϕ](https://archimed-platform.github.io/archimed-phys-user-doc/) to compute the radiation interception of each organ in the example coffee plant we are using. So the only thing we need is to transform the variables given by Archimed-ϕ in each node to match the ones we need. We use `transform!` from the MultiScaleTreeGraph package to traverse the MTG and compute the right variable for each node:

```@example usepkg
using MultiScaleTreeGraph

transform!(
    mtg,
    [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y) => :Rₛ,
    :Ra_PAR_f => (x -> x * 4.57) => :PPFD,
    (x -> 0.3) => :d,
    ignore_nothing = true
)
```

The design of `MultiScaleTreeGraph.transform!()` is very close to the one adopted by `DataFrames`. It helps us compute new variables (or attributes) from others, modify their units or rename them. Here we compute `Rₛ` from the sum of `Ra_PAR_f` (absorbed radiation flux in the PAR) and `Ra_NIR_f` (...in the NIR), `PPFD` from `Ra_PAR_f` using the conversion between W m2 to μmol m-2 s-1, and `d` using a contant value of 0.3m. Note that `sky_fraction` is already computed for each node with the right units thanks to Archimed-ϕ.

Then `PlantBiophysics.jl` takes care of the rest and simulate the energy balance over each time-step:

```@example usepkg
energy_balance!(mtg, models, weather)
```

We can visualise the outputs in 3D using PlantGeom's `viz` function. To do so we have to extract the timestep we want to color first. For example if we want to color the plant according to the value of the temperature on the first time-step, we would do:

```@example usepkg
transform!(
    mtg,
    :Tₗ => (x -> x[1]) => :Tₗ_1,
    ignore_nothing = true
)
```

And the actually plotting it:

```@example usepkg
f, ax, p = viz(mtg, color = :Tₗ_1)
colorbar(f[1, 2], p)
f
```
