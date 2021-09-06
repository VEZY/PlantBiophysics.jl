# First simulation

```@setup usepkg
using PlantBiophysics
leaf = LeafModels(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03, 12.0))
```

## Running the simulation

We just saw in the previous section how to run this first simulation:

```@example usepkg
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

leaf = LeafModels(
        energy = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        Rₛ = 13.747, skyFraction = 1.0, PPFD = 1500.0, d = 0.03
    )

energy_balance!(leaf,meteo)

DataFrame(leaf)
```

Now let's describe what is happening here.

## Meteorology

The first line of the simulation is calling [`Atmosphere`](@ref). [`Atmosphere`](@ref) is a structure used to describe what are the meteorological conditions in the atmosphere surrounding the leaf, such as the air temperature and humidity, the wind speed or the pressure.

## LeafModels

The next command is using [`LeafModels`](@ref), which is a component with a photosynthetic activity (*e.g.* a leaf). This component helps us declare which model will be used for the given processes that can be simulated. The  [`LeafModels`](@ref) implements four processes: the light interception, the energy balance, the photosynthesis, and the stomatal conductance. For each of these processes, we can choose a model that will be used for its simulation. The package provide some models, but you can also implement your own by following the design given by the package.

In our example we use the Monteith et al. (2013) model implementation for the energy balance (`energy = Monteith()`), the Farquhar et al. (1980) model for the photosynthesis (`photosynthesis = Fvcb()`), and the Medlyn et al. (2011) model for the stomatal conductance (`stomatal_conductance = Medlyn(0.03, 12.0)`). All are available from `PlantBiophysics.jl`. We don't provide any model for the light interception because there isn't any in the package right now, but we provide the input variables needed as arguments (see below).

Each model has its own structure used to provide the parameter values. For example the stomatal conductance model of Medlyn et al. (2011) need two parameters: g0 and g1. We pass both values when calling the structure here: `Medlyn(0.03, 12.0)`. In our example, we use the default values for the two other models used, they are called without passing any argument.

Then we pass different values to instantiate the input variables needed for the models: `Rₛ = 13.747, skyFraction = 1.0, PPFD = 1500.0, d = 0.03`. The variables needed to be instantiated depends on each model used, but also on their combination because some models will compute the inputs of others. One way to know which variables should be instantiated is to use [`to_initialise`](@ref):

```@example
to_initialise(
    LeafModels(
        energy = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0)
    )
)
```

When we know which parameters have to be initialized, we can get the list of the parameters for each model by looking at its field names:

```@example
fieldnames(Fvcb)
```

Or look into the documentation of the structure (e.g. `?Fvcb`) or the implementation of the model (*e.g.* `?assimilation`) to get more informations such as the units.

## energy_balance!

The simulation of the energy balance is done using [`energy_balance!`](@ref). Then Julia will choose the right implementations for each model using multiple dispatch. In our case it will use the `Monteith` implementation for [`net_radiation!`](@ref), `Fvcb!` for [`assimilation!`](@ref) and `Medlyn` for [`gs_closure`](@ref). The photosynthesis and the stomatal conductance models are called directly from the energy balance function.

## Results

The results of the computations are stored in the `status` field of the leaf. To get the value for each given variable we can call them using the dot syntax, *e.g.* for the assimilation:

```@example usepkg
leaf.status.A
```

Another simpler way to get the results is to use `DataFrame`:

```@example usepkg
DataFrame(leaf)
```

## Wrap-up

We learned to run a simple simulation, along with some details about the functions, the structures and some helper functions.

Next, we'll learn to run a simulation over several time-steps.
