# Package design

`PlantBiophysics.jl` is designed to ease the computations of biophysical processes in plants and other objects. It is part of the [Archimed platform](https://archimed-platform.github.io/), so it shares the same ontology (same concepts and terms).

```@setup usepkg
using PlantBiophysics
```

## Processes

A process in this package defines a biological or a physical phenomena.

At this time `PlantBiophysics.jl` implements three processes:

- energy balance
- photosynthesis
- stomatal conductance

## Models

### What is a model?

A process is simulated using a particular implementation of a model. Each model is implemented using a structure that lists the parameters of the model. For example PlantBiophysics provides the [`Fvcb`](@ref) structure for the implementation of the Farquhar–von Caemmerer–Berry model for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981), and the [`Medlyn`](@ref) structure for the model of Medlyn et al. (2011).

You can see the list of available models for each process in the sections about the models, *e.g.* [for photosynthesis](@ref photosynthesis_page).

### Parameterization

Users can choose which model is used to simulate a process using the [`ModelList`](@ref) structure. Let's instantiate a [`ModelList`](@ref) with the model of Farquhar et al. (1980) for the photosynthesis process and the model of Medlyn et al. (2011) for the stomatal conductance process. The corresponding structures are `Fvcb()` and `Medlyn()` respectively.

```@example usepkg
ModelList(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03, 12.0))
```

!!! tip
    We see that we only instantiated the [`ModelList`](@ref) for the photosynthesis and stomatal conductance processes. What about the energy balance? Well there is no need to give models if we have no intention to simulate them.

What happened here? We provided an instance of models to the processes. The models are provided as keyword arguments to the [`ModelList`](@ref). The keyword must match **exactly** the name of the process it simulates, *e.g.* `photosynthesis` for the photosynthesis process, because then it is used to match the models to the function than run its simulation.

We can note that the `Fvcb` model is instantiated with no parameters, and the `Medlyn` model with two parameter values. This is because models usually provide default values for their parameters, so `Fvcb` was used with default values here. We can see that `Fvcb` as actually a lot of parameters:

```@example usepkg
fieldnames(Fvcb)
```

But if we need to change the values of some parameters, we can give them as keyword arguments:

```@example usepkg
Fvcb(VcMaxRef = 250.0, JMaxRef = 300.0, RdRef = 0.5)
```

Perfect! Now is that all we need to make a simulation? Well, usually no. Models need parameters, but also input variables.

### Model initialization

Models can use three types of entries in `PlantBiophysics.jl`:

- Parameters
- Meteorological information
- Variables

Parameters are set as constant values, and stored inside the model structure. This is what we saw earlier when instantiating the `Fvcb` model.

Meteorological variables are always forced, meaning models cannot update their values, and are used as inputs only. They are provided as their own argument to the simulation.

Variables are computed by models, and can optionally be initialized before the simulation. Variables and their values are stored in the [`ModelList`](@ref), and are initialized automatically or manually.

Hence, [`ModelList`](@ref) objects store two fields:

```@example usepkg
fieldnames(ModelList)
```

The first field is a list of models associated to the processes they simulate. The second, `:status`, is used to hold all inputs and outputs of our models, called variables. For example the [`Fvcb`](@ref) model needs the leaf temperature (`Tₗ`, °C), the Photosynthetic Photon Flux Density (`PPFD`, ``μmol \cdot m^{-2} \cdot s^{-1}``) and the CO₂ concentration at the leaf surface (`Cₛ`, ppm) to run. The [`Medlyn`](@ref) model needs the assimilation (`A`, ``μmol \cdot m^{-2} \cdot s^{-1}``), the CO₂ concentration at the leaf surface (`Cₛ`, ppm) and the vapour pressure difference between the surface and the saturated air vapour pressure (`Dₗ`, kPa). We can see that using [`inputs`](@ref):

```@example usepkg
inputs(Fvcb())
```

```@example usepkg
inputs(Medlyn(0.03, 12.0))
```

Note that some variables are common between models. This is why we prefer using [`to_initialize`](@ref) instead, because it returns only the variables that need to be initialized, considering that some inputs are duplicated between models, and some inputs are computed by other models (they are outputs of a model):

```@example usepkg
to_initialize(Fvcb(),Medlyn(0.03, 12.0))
```

Or directly on a model list after instantiation:

```@example usepkg
m = ModelList(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0)
)

to_initialize(m)
```

We can also use [`is_initialized`](@ref) to know if a component is correctly initialized:

```@example usepkg
is_initialized(m)
```

And then we can initialize the component model status using [`init_status!`](@ref):

```@example usepkg
init_status!(m, Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = 1.2)
```

And check again if it worked:

```@example usepkg
is_initialized(m)
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

## Simulation

### Simulation of processes

Making a simulation is rather simple, we simply use the function with the name of the process we want to simulate:

- [`stomatal_conductance`](@ref) for the stomatal conductance
- [`photosynthesis`](@ref) for the photosynthesis
- [`energy_balance`](@ref) for the energy balance

!!! note
    All functions exist in a mutating and a non-mutating form. Just add `!` at the end of the name of the function to use the mutating form for speed! 🚀

The call to the function is the same whatever the model you choose for simulating the process. This is some magic allowed by Julia! A call to a function is made as follows:

```julia
stomatal_conductance(model_list, meteo)
photosynthesis(model_list, meteo)
energy_balance(model_list, meteo)
```

The first argument is the model list (see [`ModelList`](@ref)), and the second defines the micro-climatic conditions (more details below in [Climate forcing](@ref)).

### Example simulation

For example we can simulate the [`photosynthesis`](@ref) of a leaf like so:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = ModelList(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    status = (Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = meteo.VPD)
)

photosynthesis!(leaf, meteo)

leaf[:A]
```

### Functions forms

Each function exists on three forms, *e.g.* [`energy_balance`](@ref) has:

- `energy_balance`: the generic function that makes a copy of the components model and return the status (not very efficient but easy to use)
- `energy_balance!`: the faster generic function. But we need to extract the outputs from the component models after the simulation (note the `!` at the end of the name)
- `energy_balance!_`: the internal implementation with a method for each model. PlantBiophysics then uses multiple dispatch to choose the right method based on the model type. If you don't plan to make your own models, you'll never have to use it 🙂

If you want to implement your own models, please read this section in full first, and then [Model implementation](@ref model_implementation_page).

!!! note
    The functions can be applied on a model list only if there is a model parameterized for its corresponding process.

## Climate forcing

To make a simulation, we usually need the climatic/meteorological conditions measured close to the object or component. They are given as the second argument of the simulation functions shown before.

The package provides its own data structures to declare those conditions, and to pre-compute other required variables. The most basic data structure is a type called [`Atmosphere`](@ref), which defines the conditions for a steady-state, *i.e.* the conditions are considered at equilibrium. Another structure is available to define different consecutive time-steps: [`Weather`](@ref).

The mandatory variables to provide for an [`Atmosphere`](@ref) are: `T` (air temperature in °C), `Rh` (relative humidity, 0-1), `Wind` (the wind speed in m s-1) and `P` (the air pressure in kPa). We can declare such conditions like so:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
```

More details are available from the [dedicated section](@ref microclimate_page).

### Outputs

The `status` field of a [`ModelList`](@ref) is used to to initialize the variables before simulation and then to keep track of their values during and after the simulation. We can extract the simulation outputs of a model list using the [`status`](@ref) function.

!!! note
    Getting the status is only useful when using the mutating version of the function (*e.g.* [`energy_balance!`](@ref)), as the non-mutating version returns the output directly.

The status can either be a [`Status`](@ref) if simulating only one time-step, or a [`TimeSteps`](@ref) if several.

Let's look at the status of our previous simulated leaf:

```@setup usepkg
status(leaf)
```

We can extract the value of one variable using the `status` function, *e.g.* for the assimilation:

```@example usepkg
status(leaf, :A)
```

Or similarly using the dot syntax:

```@example usepkg
leaf.status.A
```

Or much simpler (and recommended), by indexing directly the model list:

```@example usepkg
leaf[:A]
```

Another simple way to get the results is to transform the outputs into a `DataFrame`:

```@example usepkg
DataFrame(leaf)
```

!!! note
    The output from `DataFrame` is adapted to the kind of simulation you did: one row per
    time-steps, and per component models if you simulated several.

## Model coupling

As presented above, each process is simulated using a particular model. A model can work either independently or in conjunction with other models. For example a stomatal conductance model is often associated with a photosynthesis model, *i.e.* it is called from the photosynthesis model.

Several models are provided in this package, and the user can also add new models by following the instructions in the corresponding section.

The models included in the package are listed in their own section, *i.e.* for photosynthesis, you can look at [this section](@ref photosynthesis_page).
