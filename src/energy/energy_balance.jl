"""
    energy_balance(object::AbstractComponentModel,meteo::Atmosphere,constants = Constants())
    energy_balance!(object::AbstractComponentModel,meteo::Atmosphere,constants = Constants())

Computes the energy balance of a component based on the type of the model it was parameterized
with in `object.energy`.

At the moment, two models are implemented in the package:

- [`Monteith`](@ref): the model found in Monteith and Unsworth (2013)
- `Missing`: if no computation of the energy balance is needed

# Arguments

- `object::AbstractComponentModel`: a [`Component`](@ref) struct.
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

# Note

Some models need initialisations for some variables. For example [`Monteith`](@ref) requires
to initialise a value for `Rn`, `d` and `skyFraction`. If you read the models from a file, you can
use [`init_status!`](@ref) (see examples).


# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

# Using the model of Monteith and Unsworth (2013) for energy, Farquhar et al. (1980) for
# photosynthesis, and Medlyn et al. (2011) for stomatal conductance:
leaf = LeafModels(energy = Monteith(),
            photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            Rn = 13.747, skyFraction = 1.0, PPFD = 1500.0, d = 0.03)

energy_balance(leaf,meteo)

# Using a model file:
model = read_model("a-model-file.yml")

# An example model file is available here:
# "https://raw.githubusercontent.com/VEZY/PlantBiophysics/main/test/inputs/models/plant_coffee.yml"

# Initialising the mandatory variables:
init_status!(model, Rn = 13.747, skyFraction = 1.0, PPFD = 1500.0, Tₗ = 25.0, d = 0.03)

# Running a simulation for all component types in the same scene:
energy_balance!(model, meteo)

model["Leaf"].status.Rn
model["Leaf"].status.A
model["Leaf"].status.Cᵢ
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
function energy_balance(object::AbstractComponentModel,meteo::Atmosphere,constants = Constants())
    object_tmp = deepcopy(object)
    energy_balance!(object_tmp,meteo,constants)
    return object_tmp.status
end

function energy_balance!(object::AbstractComponentModel,meteo::Atmosphere,constants = Constants())
    is_init = is_initialised(object)
    !is_init && error("Some variables must be initialized before simulation")

    net_radiation!(object,meteo,constants)
    return nothing
end

function energy_balance!(object::Dict{String,PlantBiophysics.AbstractComponentModel},meteo::Atmosphere,constants = Constants())
    for i in keys(object)
        energy_balance!(object[i],meteo,constants)
    end
    return nothing
end
