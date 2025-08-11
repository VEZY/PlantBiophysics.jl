# Simple simulation

```@setup usepkg
using PlantBiophysics, PlantSimEngine
```

## Running a simple simulation

Here is a first simple simulation of the coupled energy balance on a leaf over one meteorological time-step:

```@example usepkg
using PlantBiophysics, PlantSimEngine

meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

leaf = ModelList(
        Monteith(),
        Fvcb(),
        Medlyn(0.03, 12.0),
        status = (Ra_SW_f = 13.747, sky_fraction = 1.0, aPPFD = 1500.0, d = 0.03)
    )

out_sim = run!(leaf,meteo)

out_sim
```

Now let's describe what is happening here.

## PlantSimEngine

PlantBiophysics is nothing but an extension of [PlantSimEngine.jl](https://virtualplantlab.github.io/PlantSimEngine.jl). What it really does is implementing biophysical models for PlantSimEngine. So when you use PlantBiophysics, you'll also need to import PlantSimEngine too.

## Meteorology

The first line of the simulation is calling `Atmosphere`. `Atmosphere` is a structure used to describe what are the meteorological conditions in the atmosphere surrounding the leaf, such as the air temperature and humidity, the wind speed or the pressure. It comes from the [PlantMeteo.jl](https://palmstudio.github.io/PlantMeteo.jl/stable/) package, but it is also exported by PlantSimEngine.

## ModelList

The next command is using `ModelList` (from PlantSimEngine), which helps us associate models (*e.g.* `Monteith()`) to processes (*e.g.* `energy_balance`). Currently `PlantBiophysics.jl` implements three processes: the energy balance, the photosynthesis, and the stomatal conductance. For each of these processes, we can choose a model that will be used for its simulation. The package provides processes and models, but you can also implement your own by following the [tutorial here](@ref model_implementation_page).

In our example we use the Monteith et al. (2013) model implementation for the energy balance (`Monteith()`), the Farquhar et al. (1980) model for the photosynthesis (`Fvcb()`), and the Medlyn et al. (2011) model for the stomatal conductance (`Medlyn(0.03, 12.0)`). All are available from `PlantBiophysics.jl`.

Each model has its own structure used to provide the parameter values. For example the stomatal conductance model of Medlyn et al. (2011) need two parameters: `g0` and `g1`. We pass both values when calling the structure here: `Medlyn(0.03, 12.0)`. In our example, we use the default values for the two other models used, so they are called without passing any argument.

Then we provide the initializations for some variables in the status keyword argument: `Ra_SW_f = 13.747, sky_fraction = 1.0, aPPFD = 1500.0, d = 0.03`. The variables that need to be initialized depend on the combination of models we are using. One way to know which variables should be instantiated is to use `to_initialize` from `PlantSimEngine.jl`:

```@example usepkg
to_initialize(ModelList(Monteith(), Fvcb(), Medlyn(0.03, 12.0)))
```

It returns a list of the variables that need to be initialized for each independent process. If some processes are coupled, it only returns the ones from the root process that calls the others.

When we know which parameters have to be initialized, we can get the list of the parameters for each model by looking at its field names:

```@example usepkg
fieldnames(Fvcb)
```

Or look into the documentation of the structure (e.g. `?Fvcb`) or the documentation of the process (*e.g.* ?[`AbstractPhotosynthesisModel`](@ref)) to get more information such as the units.

## Model coupling

`PlantSimEngine` handles all model coupling and the order of execution of the processes. The user only needs to provide the list of models and the initializations. The package takes care of the rest by building a dependency graph and executing the processes in the right order considering the soft and hard dependencies. You can take a look at these concepts in the [PlantSimEngine documentation](https://virtualplantlab.github.io/PlantSimEngine.jl/stable/model_execution/).

## Results

The results of the computations are stored in the outputs structure returned by the `run!` function. The last timestep values can also be found in the `status` field of the `ModelList`. To get the value for each given variable we can just index the output structure like so:

```@example usepkg
out_sim[:A]
```

Another simpler way to get all the results at once is to use `DataFrame`:

```@example usepkg
using DataFrames
PlantSimEngine.convert_outputs(out_sim, DataFrame)
```

Or simply by printing the object:

```@example usepkg
out_sim
```

## Wrap-up

We learned to run a simple simulation, along with some details about the simulation, the structures and some helper functions.

Next, we'll learn to run a simulation over several time-steps.
