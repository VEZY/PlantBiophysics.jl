# Package design

`PlantBiophysics.jl` is designed to ease the computations of biophysical processes in plants and other objects. It uses `PlantSimEngine.jl`, so it shares the same ontology (same concepts and terms).

```@setup usepkg
using PlantBiophysics, PlantSimEngine, PlantMeteo
using DataFrames
```

## Definitions

### Processes

A process is defined in PlantSimEngine as a biological or a physical phenomena. At this time `PlantBiophysics.jl` implements four processes:

- light interception
- energy balance
- photosynthesis
- stomatal conductance

### Models

A process is simulated using a particular implementation of a model. Each model is implemented using a structure that lists the parameters of the model. For example, PlantBiophysics provides the [`Beer`](@ref) structure for the implementation of the Beer-Lambert law of light extinction.

You can see the list of available models for each process in the sections about the models, *e.g.* [here for photosynthesis](@ref photosynthesis_page).

Models can use three types of entries:

- Parameters
- Meteorological information
- Variables

Parameters are constant values that are used by the model to compute its outputs. Meteorological information are values that are provided by the user and are used as inputs to the model. Variables are computed by the model and can optionally be initialized before the simulation.

Users can choose which model is used to simulate a process using the `ModelList` structure from PlantSimEngine. `ModelList` is also used to store the values of the parameters, and to initialize variables.

Let's instantiate a `ModelList` with the Beer-Lambert model of light extinction. The model is implemented with the [`Beer`](@ref) structure and has only one parameter: the extinction coefficient (`k`).

```@example usepkg
using PlantSimEngine, PlantBiophysics
ModelList(Beer(0.5))
```

What happened here? We provided an instance of a model to a `ModelList` that automatically associates it to the process it simulates (*i.e.* the light interception).

!!! tip
    We see that we only instantiated the `ModelList` for the light extinction process. What about the others like photosynthesis or energy balance ? Well there is no need to give models if we have no intention to simulate them.

## Parameters

A parameter is a constant value that is used by a model to compute its outputs. For example, the Beer-Lambert model uses the extinction coefficient (`k`) to compute the light extinction. The Beer-Lambert model is implemented with the [`Beer`](@ref) structure, which has only one field: `k`. We can see that using `fieldnames`:

```@example usepkg
fieldnames(Beer)
```

Some models are shipped with default values for their parameters. For example, the [`Monteith`](@ref) model that simulates the energy balance has a default value for all its parameters. Here are the parameter names:

```@example usepkg
fieldnames(Monteith)
```

And their default values:

```@example usepkg
Monteith()
```

But if we need to change the values of some parameters, we can usually give them as keyword arguments:

```@example usepkg
Monteith(maxiter = 100, ΔT = 0.001)
```

Perfect! Now is that all we need to make a simulation? Well, usually no. Models need parameters, but also input variables.

## Variables (inputs, outputs)

Variables are computed by models, and can optionally be initialized before the simulation. Variables and their values are stored in the `ModelList`, and are initialized automatically or manually.

Hence, `ModelList` objects store two fields:

```@example usepkg
fieldnames(ModelList)
```

The first field is a list of models associated to the processes they simulate. The second, `:status`, is used to hold all inputs and outputs of our models, called variables. For example the [`Beer`](@ref) model needs the leaf area index (`LAI`, m^{2} \cdot m^{-2}) to run.

We can see which variables are needed as inputs using `inputs` from PlantSimEngine:

```@example usepkg
using PlantSimEngine
inputs(Beer(0.5))
```

We can also see the outputs of the model using `outputs` from PlantSimEngine:

```@example usepkg
using PlantSimEngine
outputs(Beer(0.5))
```

If we instantiate a `ModelList` with the Beer-Lambert model, we can see that the `:status` field has two variables: `LAI` and `PPDF`. The first is an input, the second an output.

```@example usepkg
using PlantSimEngine, PlantBiophysics
m = ModelList(Beer(0.5))
keys(m.status)
```

To know which variables should be initialized, we can use `to_initialize` from PlantSimEngine:

```@example usepkg
m = ModelList(Beer(0.5))

to_initialize(m)
```

Their values are uninitialized though (hence the warnings):

```@example usepkg
(m[:LAI], m[:aPPFD])
```

Uninitialized variables have often the value returned by `typemin()`, *e.g.* `-Inf` for `Float64`:

```@example usepkg
typemin(Float64)
```

!!! tip
    Prefer using `to_initialize` rather than `inputs` to check which variables should be initialized. `inputs` returns the variables that are needed by the model to run, but `to_initialize` returns the variables that are needed by the model to run and that are not initialized. Also `to_initialize` is more clever when coupling models (see below).

We can initialize the variables by providing their values to the status at instantiation:

```@example usepkg
m = ModelList(Beer(0.5), status = (LAI = 2.0,))
```

Or after instantiation using `init_status!` (from PlantSimEngine):

```@example usepkg
m = ModelList(Beer(0.5))

init_status!(m, LAI = 2.0)
```

We can check if a component is correctly initialized using `is_initialized` (from PlantSimEngine):

```@example usepkg
is_initialized(m)
```

Some variables are inputs of models, but outputs of other models. When we couple models, we have to be careful to initialize only the variables that are not computed.

## Climate forcing

To make a simulation, we usually need the climatic/meteorological conditions measured close to the object or component.

The `PlantMeteo.jl` package provides a data structure to declare those conditions, and to pre-compute other required variables. The most basic data structure is a type called `Atmosphere`, which defines the conditions for a steady-state, *i.e.* the conditions are considered at equilibrium. Another structure is available to define different consecutive time-steps: `Weather`.

The mandatory variables to provide for an `Atmosphere` are: `T` (air temperature in °C), `Rh` (relative humidity, 0-1), `Wind` (the wind speed in m s-1) and `P` (the air pressure in kPa). We can declare such conditions like so:

```@example usepkg
using PlantMeteo
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
```

More details are available from the [dedicated section](@ref microclimate_page).

## Simulation

### Simulation of processes

Making a simulation is rather simple, we simply use the `run!` function provided by `PlantSimEngine`:

```julia
run!(model_list, meteo)
```

The first argument is the model list (see `ModelList` from `PlantSimEngine`), and the second defines the micro-climatic conditions (more details below in [Climate forcing](@ref)).

The `ModelList` should be initialized for the given process before calling `run!`. See [Variables (inputs, outputs)](@ref) for more details.

### Example simulation

For example we can simulate the `stomatal_conductance` of a leaf like so:

```@example usepkg
using PlantMeteo, PlantSimEngine, PlantBiophysics
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = ModelList(
    Medlyn(0.03, 12.0),
    status = (A = 20.0, Dₗ = meteo.VPD, Cₛ = 400.0)
)

run!(leaf, meteo)

leaf[:Gₛ]
```

### Outputs

The `status` field of a `ModelList` is used to initialize the variables before simulation and then to keep track of their values during and after the simulation. We can extract the simulation outputs of a model list using the `status` function (from PlantSimEngine).

The status can either be a `Status` type if simulating only one time-step, or a `TimeStepTable` (from `PlantMeteo`) if several.

Let's look at the status of our previous simulated leaf:

```@setup usepkg
status(leaf)
```

We can extract the value of one variable using the `status` function, *e.g.* for the stomatal conductance:

```@example usepkg
status(leaf, :Gₛ)
```

Or similarly using the dot syntax:

```@example usepkg
leaf.status.Gₛ
```

Or much simpler (and recommended), by indexing directly the model list:

```@example usepkg
leaf[:Gₛ]
```

Another simple way to get the results is to transform the outputs into a `DataFrame`:

```@example usepkg
using DataFrames
DataFrame(leaf)
```

!!! note
    The output from `DataFrame` is adapted to the kind of simulation you did: one row per
    time-steps, and per component models if you simulated several.

## Model coupling

A model can work either independently or in conjunction with other models. For example a stomatal conductance model is often associated with a photosynthesis model, *i.e.* it is called from the photosynthesis model.

Several models proposed in `PlantBiophysics.jl` are hard-coupled models, *i.e.* one model calls another. For example, the [`Fvcb`](@ref) structure is the implementation of the Farquhar–von Caemmerer–Berry model for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981) calls a stomatal conductance model. Hence, using [`Fvcb`](@ref) requires a stomatal conductance model in the `ModelList` to compute Gₛ.

We can use the stomatal conductance model of Medlyn et al. (2011) as an example to compute it. It is implemented with the [`Medlyn`](@ref) structure. We can then create a `ModelList` with the two models:

```@example usepkg
ModelList(Fvcb(), Medlyn(0.03, 12.0))
```

Now this instantiation returns some warnings saying we need to initialize some variables.

The [`Fvcb`](@ref) model requires the following variables as inputs:

```@example usepkg
inputs(Fvcb())
```

And the [`Medlyn`](@ref) model requires the following variables:

```@example usepkg
inputs(Medlyn(0.03, 12.0))
```

We see that `A` is needed as input of `Medlyn`, but we also know that it is an output of `Fvcb`. This is why we prefer using `to_initialize` from `PlantSimEngine.jl` instead of `inputs`, because it returns only the variables that need to be initialized, considering that some inputs are duplicated between models, and some are computed by other models (they are outputs of a model):

```@example usepkg
to_initialize(ModelList(Fvcb(), Medlyn(0.03, 12.0)))
```

The most straightforward way of initializing a model list is by giving the initializations to the `status` keyword argument during instantiation:

```@example usepkg
m = ModelList(
    Fvcb(),
    Medlyn(0.03, 12.0),
    status = (Tₗ = 25.0, aPPFD = 1000.0, Cₛ = 400.0, Dₗ = 0.82)
)
```

Our component models structure is now fully parameterized and initialized for a simulation!

Let's simulate it:

```@example usepkg
run!(m)
```

!!! tip
    The models included in the package are listed in their own section, *i.e.* [here for photosynthesis](@ref photosynthesis_page).
