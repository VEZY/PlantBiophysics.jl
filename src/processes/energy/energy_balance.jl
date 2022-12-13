# Generate all methods for the energy_balance process: several meteo time-steps, components,
#  over an MTG, and the mutating /non-mutating versions
@gen_process_methods "energy_balance" """
At the moment, two models are implemented in the package:

- [`Monteith`](@ref): the model found in Monteith and Unsworth (2013)
- `Missing`: if no computation of the energy balance is needed

# Note

Some models need input values for some variables. For example [`Monteith`](@ref) requires a
value for `Rₛ`, `d` and `sky_fraction`. If you read the models from a file, you can
use `init_status!` (see examples).

# Examples

```julia
# ---Simple example---

meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

# Using the model of Monteith and Unsworth (2013) for energy, Farquhar et al. (1980) for
# photosynthesis, and Medlyn et al. (2011) for stomatal conductance:
leaf =
    ModelList(
        energy_balance = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        status = (Rₛ = 13.747, sky_fraction = 1.0, PPFD = 1500.0, d = 0.03)
    )

energy_balance(leaf,meteo)

# ---Using several components---

leaf2 = copy(leaf)
leaf2.status.PPFD = 800.0

energy_balance([leaf,leaf2],meteo)

# You can use a Dict if you'd like to keep track of the leaf in the returned DataFrame:
energy_balance(Dict(:leaf1 => leaf, :leaf2 => leaf2), meteo)

# ---Using several meteo time-steps---

w = Weather([Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
             Atmosphere(T = 25.0, Wind = 1.5, P = 101.3, Rh = 0.55)],
             (site = "Test site",))

energy_balance(leaf, w)

# ---Using several meteo time-steps and several components---

energy_balance(Dict(:leaf1 => leaf, :leaf2 => leaf2), w)

# ---Using a model file---

model = read_model(joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","models","plant_coffee.yml"))

# An example model file is available here:
# "https://raw.githubusercontent.com/VEZY/PlantBiophysics/main/test/inputs/models/plant_coffee.yml"

# Initialising the mandatory variables:
init_status!(model, Rₛ = 13.747, sky_fraction = 1.0, PPFD = 1500.0, Tₗ = 25.0, d = 0.03)

# NB: To know which variables has to be initialized according to the models used, you can use
# `to_initialize(ComponentModels)`, *e.g.*:
to_initialize(model["Leaf"])

# Running a simulation for all component types in the same scene:
energy_balance!(model, meteo)

model["Leaf"].status.Rn
model["Leaf"].status.A
model["Leaf"].status.Cᵢ

# ---Simulation on a full plant using an MTG---


using PlantBiophysics, MultiScaleTreeGraph, PlantGeom, GLMakie, Dates

file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf")
mtg = read_opf(file)

# Import the meteorology:
meteo = read_weather(
    "archimed/meteo.csv",
    :temperature => :T,
    :relativeHumidity => (x -> x ./ 100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)

# Make the models:
models = Dict(
    "Leaf" =>
        ModelList(
            energy_balance = Monteith(),
            photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            status = (d = 0.03,)
        )
)

# List the MTG attributes:
names(mtg)
# We have the skyFraction already, but not Rₛ and PPFD, so we must compute them first.
# Rₛ is the shortwave radiation (or global radiation), so it is the sum of Ra_PAR_f and Ra_NIR_f.
# PPFD is the PAR in μmol m-2 s-1, so Ra_PAR_f * 4.57.

# We can compute them using the following code (transform! comes from MultiScaleTreeGraph.jl):
transform!(
    mtg,
    [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y) => :Rₛ,
    :Ra_PAR_f => (x -> x * 4.57) => :PPFD,
    ignore_nothing = true
)

# Making the simulation:
energy_balance!(mtg, models, status, meteo)

# Pull the leaf temperature of the first step:
transform!(
    mtg,
    :Tₗ => (x -> x[1]) => :Tₗ_1,
    ignore_nothing = true
)

# Vizualise the output:
viz(mtg, color = :Tₗ_1)
```

# References

Duursma, R. A., et B. E. Medlyn. 2012. « MAESPA: a model to study interactions between water
limitation, environmental drivers and vegetation function at tree and stand levels, with an
example application to [CO2] × drought interactions ». Geoscientific Model Development 5 (4):
919‑40. https://doi.org/10.5194/gmd-5-919-2012.

Monteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i)
Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition),
edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.

Schymanski, Stanislaus J., et Dani Or. 2017. « Leaf-Scale Experiments Reveal an Important
Omission in the Penman–Monteith Equation ». Hydrology and Earth System Sciences 21 (2): 685‑706.
https://doi.org/10.5194/hess-21-685-2017.

Vezy, Rémi, Mathias Christina, Olivier Roupsard, Yann Nouvellon, Remko Duursma, Belinda Medlyn,
Maxime Soma, et al. 2018. « Measuring and modelling energy partitioning in canopies of varying
complexity using MAESPA model ». Agricultural and Forest Meteorology 253‑254 (printemps): 203‑17.
https://doi.org/10.1016/j.agrformet.2018.02.005.
"""
