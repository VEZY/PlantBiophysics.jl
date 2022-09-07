# Package design

`PlantBiophysics.jl` is designed to ease the computations of biophysical processes in plants and other objects. It is part of the [Archimed platform](https://archimed-platform.github.io/), so it shares the same ontology (same concepts and terms).

```@setup usepkg
using PlantBiophysics
```

## Definitions

### Processes

A process in this package defines a biological or a physical phenomena. At this time `PlantBiophysics.jl` implements four processes:

- light interception
- energy balance
- photosynthesis
- stomatal conductance

### Models

A process is simulated using a particular implementation of a model. Each model is implemented using a structure that lists the parameters of the model. For example, PlantBiophysics provides the [`Beer`](@ref) structure for the implementation of the Beer-Lambert law of light extinction.

You can see the list of available models for each process in the sections about the models, *e.g.* [here for photosynthesis](@ref photosynthesis_page).

Models can use three types of entries in `PlantBiophysics.jl`:

- Parameters
- Meteorological information
- Variables

Parameters are constant values that are used by the model to compute its outputs. Meteorological information are values that are provided by the user and are used as inputs to the model. Variables are computed by the model and can optionally be initialized before the simulation.

Users can choose which model is used to simulate a process using the [`ModelList`](@ref) structure. `ModelList` is also used to store the values of the parameters, and to initialize variables.

Let's instantiate a [`ModelList`](@ref) with the Beer-Lambert model of light extinction. The model is implemented with the [`Beer`](@ref) structure and has only one parameter: the extinction coefficient (`k`).

```@example usepkg
ModelList(light_extinction = Beer(0.5))
```

What happened here? We provided an instance of a model to the process it simulates. The model is provided as a keyword argument to the [`ModelList`](@ref), with the process name given as the keyword, and the instantiated model as the value. The keyword must match **exactly** the name of the process it simulates, *e.g.* `photosynthesis` for the photosynthesis process, because it is used to match the models to the function than run its simulation. The four processes provided by default are implement with the following functions: `light_interception`, `energy_balance`, `photosynthesis` and `stomatal_conductance`.

!!! tip
    We see that we only instantiated the [`ModelList`](@ref) for the light extinction process. What about the others like photosynthesis or energy balance ? Well there is no need to give models if we have no intention to simulate them.

## Parameters

A parameter is a constant value that is used by a model to compute its outputs. For example, the Beer-Lambert model uses the extinction coefficient (`k`) to compute the light extinction. The Beer-Lambert model is implemented with the [`Beer`](@ref) structure, which has only one field: `k`. We can see that using [`fieldnames`](@ref):

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

Variables are computed by models, and can optionally be initialized before the simulation. Variables and their values are stored in the [`ModelList`](@ref), and are initialized automatically or manually.

Hence, [`ModelList`](@ref) objects store two fields:

```@example usepkg
fieldnames(ModelList)
```

The first field is a list of models associated to the processes they simulate. The second, `:status`, is used to hold all inputs and outputs of our models, called variables. For example the [`Beer`](@ref) model needs the leaf area index (`LAI`, m^{2} \cdot m^{-2}) to run.

We can see which variables are needed as inputs using [`inputs`](@ref):

```@example usepkg
inputs(Beer(0.5))
```

We can also see the outputs of the model using [`outputs`](@ref):

```@example usepkg
outputs(Beer(0.5))
```

If we instantiate a [`ModelList`](@ref) with the Beer-Lambert model, we can see that the `:status` field has two variables: `LAI` and `PPDF`. The first is an input, the second an output.

```@example usepkg
m = ModelList(light_extinction = Beer(0.5))
keys(m.status)
```

To know which variables should be initialized, we can use [`to_initialize`](@ref):

```@example usepkg

```@example usepkg
m = ModelList(light_extinction = Beer(0.5))

to_initialize(m)
```

Their values are uninitialized though (hence the warnings):

```@example usepkg
(m[:LAI], m[:PPFD])
```

Uninitialized variables have the value returned by `typemin()`, *e.g.* `-Inf` for `Float64`:

```@example usepkg
typemin(Float64)
```

!!! tip
    Prefer using `to_initialize` rather than `inputs` to check which variables should be initialized. `inputs` returns the variables that are needed by the model to run, but `to_initialize` returns the variables that are needed by the model to run and that are not initialized. Also `to_initialize` is more clever when coupling models (see below).

We can initialize the variables by providing their values to the status at instantiation:

```@example usepkg
m = ModelList(light_extinction = Beer(0.5), status = (LAI = 2.0,))
```

Or after instantiation using [`init_status!`](@ref):

```@example usepkg
m = ModelList(light_extinction = Beer(0.5))

init_status!(m, LAI = 2.0)
```

We can check if a component is correctly initialized using [`is_initialized`](@ref):

```@example usepkg
is_initialized(m)
```

Some variables are inputs of models, but outputs of other models. When we couple models, we have to be careful to initialize only the variables that are not computed.

## Climate forcing

To make a simulation, we usually need the climatic/meteorological conditions measured close to the object or component.

The package provides its own data structures to declare those conditions, and to pre-compute other required variables. The most basic data structure is a type called [`Atmosphere`](@ref), which defines the conditions for a steady-state, *i.e.* the conditions are considered at equilibrium. Another structure is available to define different consecutive time-steps: [`Weather`](@ref).

The mandatory variables to provide for an [`Atmosphere`](@ref) are: `T` (air temperature in °C), `Rh` (relative humidity, 0-1), `Wind` (the wind speed in m s-1) and `P` (the air pressure in kPa). We can declare such conditions like so:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
```

More details are available from the [dedicated section](@ref microclimate_page).

## Simulation

### Simulation of processes

Making a simulation is rather simple, we simply use the function with the name of the process we want to simulate:

- [`stomatal_conductance`](@ref) for the stomatal conductance
- [`photosynthesis`](@ref) for the photosynthesis
- [`energy_balance`](@ref) for the energy balance
- [`light_interception`](@ref) for the energy balance

!!! note
    All functions exist in a mutating and a non-mutating form. Just add `!` at the end of the name of the function (*e.g.* `energy_balance!`) to use the mutating form for speed! 🚀

The call to the function is the same whatever the model you choose for simulating the process. This is some magic allowed by Julia! A call to a function is made as follows:

```julia
stomatal_conductance(model_list, meteo)
photosynthesis(model_list, meteo)
energy_balance(model_list, meteo)
light_interception(model_list, meteo)
```

The first argument is the model list (see [`ModelList`](@ref)), and the second defines the micro-climatic conditions (more details below in [Climate forcing](@ref)).

The `ModelList` should be initialized for the given process before calling the function. See [Variables (inputs, outputs)](@ref) for more details.

### Example simulation

For example we can simulate the [`stomatal_conductance`](@ref) of a leaf like so:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = ModelList(
    stomatal_conductance = Medlyn(0.03, 12.0),
    status = (A = 20.0, Cₛ = 400.0, Dₗ = meteo.VPD)
)

stomatal_conductance!(leaf, meteo)

leaf[:Gₛ]
```

### Functions forms

Each function has three forms. For example [`energy_balance`](@ref) has:

- `energy_balance`: the generic function that makes a copy of the `modelList` and return the status (not very efficient but easy to use)
- `energy_balance!`: the faster generic function. But we need to extract the outputs from the component models after the simulation (note the `!` at the end of the name)
- `energy_balance!_`: the internal implementation with a method for each model. PlantBiophysics then uses multiple dispatch to choose the right method based on the model type. If you don't plan to make your own models, you'll never have to use it 🙂

If you want to implement your own models, please read this section in full first, and then [Model implementation](@ref model_implementation_page).

!!! note
    The functions can be applied on a model list only if there is a model parameterized for its corresponding process.

### Outputs

The `status` field of a [`ModelList`](@ref) is used to initialize the variables before simulation and then to keep track of their values during and after the simulation. We can extract the simulation outputs of a model list using the [`status`](@ref) function.

!!! note
    Getting the status is only useful when using the mutating version of the function (*e.g.* [`energy_balance!`](@ref)), as the non-mutating version returns the output directly.

The status can either be a [`Status`](@ref) if simulating only one time-step, or a [`TimeSteps`](@ref) if several.

Let's look at the status of our previous simulated leaf:

```@setup usepkg
status(leaf)
```

We can extract the value of one variable using the `status` function, *e.g.* for the assimilation:

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
DataFrame(leaf)
```

!!! note
    The output from `DataFrame` is adapted to the kind of simulation you did: one row per
    time-steps, and per component models if you simulated several.

## Model coupling

A model can work either independently or in conjunction with other models. For example a stomatal conductance model is often associated with a photosynthesis model, *i.e.* it is called from the photosynthesis model.

Several models proposed in `PlantBiophysics.jl` are coupled models. For example, the [`Fvcb`](@ref) structure is the implementation of the Farquhar–von Caemmerer–Berry model for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981) that is coupled to a stomatal conductance model. Hence, using [`Fvcb`](@ref) requires a stomatal conductance model in the `ModelList` to compute Gₛ.

We can use the stomatal conductance model of Medlyn et al. (2011) as an example to compute it. It is implemented with the [`Medlyn`](@ref) structure. We can then create a `ModelList` with the two models:

```@example usepkg
ModelList(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03, 12.0))
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

We see that `A` is needed as input of `Medlyn`, but we also know that it is an output of `Fvcb`. This is why we prefer using [`to_initialize`](@ref) instead of [`inputs`](@ref), because it returns only the variables that need to be initialized, considering that some inputs are duplicated between models, and some are computed by other models (they are outputs of a model):

```@example usepkg
to_initialize(Fvcb(),Medlyn(0.03, 12.0))
```

We can also use it directly on a model list after instantiation:

```@example usepkg
m = ModelList(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0)
)

to_initialize(m)
```

The most straightforward way of initializing a model list is by giving the initializations to the `status` keyword argument during instantiation:

```@example usepkg
m = ModelList(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    status = (Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = 0.82)
)
```

Our component models structure is now fully parameterized and initialized for a simulation!

Let's simulate it:

```@example usepkg
photosynthesis(m)
```

!!! tip
    The models included in the package are listed in their own section, *i.e.* [here for photosynthesis](@ref photosynthesis_page). Users are also encouraged to develop their own models by following the instructions in the [corresponding section](@ref model_implementation_page).
