# Simple simulation

```@setup usepkg
using PlantBiophysics
```

## Running a simple simulation

Here is a first simple simulation of the coupled energy balance on a leaf over one meteorological time-step:

```@example usepkg
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

leaf = ModelList(
        energy_balance = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        Rₛ = 13.747, sky_fraction = 1.0, PPFD = 1500.0, d = 0.03
    )

energy_balance!(leaf,meteo)

DataFrame(leaf)
```

Now let's describe what is happening here.

## Meteorology

The first line of the simulation is calling [`Atmosphere`](@ref). [`Atmosphere`](@ref) is a structure used to describe what are the meteorological conditions in the atmosphere surrounding the leaf, such as the air temperature and humidity, the wind speed or the pressure.

## ModelList

The next command is using [`ModelList`](@ref), which is a component models structure with a photosynthetic activity (*e.g.* a leaf). This component models helps us declare which model will be used for the given processes that can be simulated. The  [`ModelList`](@ref) implements four processes: the light interception, the energy balance, the photosynthesis, and the stomatal conductance. For each of these processes, we can choose a model that will be used for its simulation. The package provides some models, but you can also implement your own by following the [tutorial here](@ref model_implementation_page).

In our example we use the Monteith et al. (2013) model implementation for the energy balance (`energy_balance = Monteith()`), the Farquhar et al. (1980) model for the photosynthesis (`photosynthesis = Fvcb()`), and the Medlyn et al. (2011) model for the stomatal conductance (`stomatal_conductance = Medlyn(0.03, 12.0)`). All are available from `PlantBiophysics.jl`. We don't provide any model for the light interception because there isn't any in the package right now, but we provide the input variables needed as arguments (see below).

Each model has its own structure used to provide the parameter values. For example the stomatal conductance model of Medlyn et al. (2011) need two parameters: g0 and g1. We pass both values when calling the structure here: `Medlyn(0.03, 12.0)`. In our example, we use the default values for the two other models used, they are called without passing any argument.

Then we pass different values to instantiate the input variables needed for the models: `Rₛ = 13.747, sky_fraction = 1.0, PPFD = 1500.0, d = 0.03`. The variables needed to be instantiated depends on each model used, but also on their combination because some models will compute the inputs of others. One way to know which variables should be instantiated is to use [`to_initialise`](@ref):

```@example usepkg
to_initialise(
    ModelList(
        energy_balance = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0)
    )
)
```

When we know which parameters have to be initialized, we can get the list of the parameters for each model by looking at its field names:

```@example usepkg
fieldnames(Fvcb)
```

Or look into the documentation of the structure (e.g. `?Fvcb`) or the implementation of the model (*e.g.* ?[`photosynthesis`](@ref)) to get more informations such as the units.

## energy_balance

The simulation of the energy balance is done using [`energy_balance!`](@ref). Then Julia will choose the right implementations for each model using multiple dispatch. In our case it will use the `Monteith` implementation for [`PlantBiophysics.energy_balance!_`](@ref), `Fvcb` for [`PlantBiophysics.photosynthesis!_`](@ref) and `Medlyn` for [`PlantBiophysics.gs_closure`](@ref). The photosynthesis and the stomatal conductance models are called directly from the energy balance function.

## Results

The results of the computations are stored in the `status` field of the leaf. To get the value for each given variable we can just index the object like so:

```@example usepkg
leaf[:A]
```

Another simpler way to get the results is to use `DataFrame`:

```@example usepkg
DataFrame(leaf)
```

## Wrap-up

We learned to run a simple simulation, along with some details about the functions, the structures and some helper functions.

Next, we'll learn to run a simulation over several time-steps.
