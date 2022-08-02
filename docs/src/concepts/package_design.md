# Package design

`PlantBiophysics.jl` is designed to ease the computations of biophysical processes in plants and other objects. It is part of the [Archimed platform](https://archimed-platform.github.io/), so it shares the same ontology (same concepts and terms).

```@setup usepkg
using PlantBiophysics
```

## Components model

### Components

A component is the most basic structural unit of an object. Its nature depends on the object itself, and the scale of the description. We can take a plant as an object for example. Reproductive organs aside, we can describe a plant with three different types of organs:

- the leaves
- the internodes
- the roots

Those three organs we present here are what we call components.

!!! note
    Of course we could describe the plant at a coarser (*e.g.* axis) or finer (*e.g.* growth units) scale.

PlantBiophysics doesn't implement components *per se*, because it is more the job of other packages. However, it provides components models.

!!! tip
    [MultiScaleTreeGraph](https://vezy.github.io/MultiScaleTreeGraph.jl/stable/) implements a way to describe a plant as a tree data-structure. PlantBiophysics compose well with MTGs and provides methods for computing processes over such data.

### Component models description

Components models are structures that define which models are used to simulate the biophysical processes of a component.

PlantBiophysics provides the [`ModelList`](@ref) and the more generic [`ComponentModels`](@ref) component models. The first one is designed to represent a photosynthetic organ such as a leaf, and the second for a more generic organ such as wood for example.

!!! tip
    These are provided as defaults, but you can easily define your own component models if you want, and then implement the models for each of its processes. See the [Implement a new component models](@ref) section for more details.

### Processes

A process in this package defines a biological or a physical phenomena associated to a component. For example [`ModelList`](@ref) implements four processes:

- radiation interception
- energy balance
- photosynthesis
- stomatal conductance

We can list the processes of a component models structure using `fieldnames`:

```@example usepkg
fieldnames(ModelList)
```

We can see there is a fifth field along the processes called `:status`. This one is mandatory for all component models, and is used to initialise the simulated variables and keep track of their values during the simulation.

Each process is simulated using a model.

## Models

### What is a model?

A process is simulated using a particular implementation of a model. The user can choose which model is used to simulate a process when instantiating the component models.

You can see the list of available models for each processes in the sections about the models, *e.g.* [for photosynthesis](@ref photosynthesis_page).

Each model is implemented using a structure that lists the parameters of the model. For example PlantBiophysics provides the [`Fvcb`](@ref) structure for the implementation of the Farquhar–von Caemmerer–Berry model for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981), and the [`Medlyn`](@ref) structure for the model of Medlyn et al. (2011).

### Parameterization

To simulate a process for a component models we need to parameterize it with a given model.

Let's instantiate a [`ModelList`](@ref) with the model of Farquhar et al. (1980) for the photosynthesis and the model of Medlyn et al. (2011) for the stomatal conductance. The corresponding structures are `Fvcb()` and `Medlyn()` respectively.

```@example usepkg
ModelList(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03, 12.0))
```

!!! tip
    We see that we only instantiated the [`ModelList`](@ref) for the photosynthesis and stomatal conductance processes. What about the radiation interception and the energy balance? Well there is no need to give models if we have no intention to simulate them. In this case they are defines as `missing` by default.

OK so what happened here? We provided an instance of models to the processes. But why Fvcb has no parameters and Medlyn has two? Well, models usually provide default values for their parameter. We can see that the `Fvcb` model as actually a lot of parameters:

```@example usepkg
fieldnames(Fvcb)
```

We just used the defaults. But if we need to change the values of some parameters, we can give them as keyword arguments:

```@example usepkg
Fvcb(VcMaxRef = 250.0, JMaxRef = 300.0, RdRef = 0.5)
```

Perfect! Now is that all we need for making a simulation? Well, usually no. Models need parameters, but also input variables.

### Model initialisation

Remember that our component models have a field named `:status`? Well this status is actually used to hold all inputs and outputs of our models. For example the [`Fvcb`](@ref) model needs the leaf temperature (`Tₗ`, Celsius degree), the Photosynthetic Photon Flux Density (`PPFD`, ``μmol \cdot m^{-2} \cdot s^{-1}``) and the CO₂ concentration at the leaf surface (`Cₛ`, ppm) to run. The [`Medlyn`](@ref) model needs the assimilation (`A`, ``μmol \cdot m^{-2} \cdot s^{-1}``), the CO₂ concentration at the leaf surface (`Cₛ`, ppm) and the vapour pressure difference between the surface and the saturated air vapour pressure (`Dₗ`, kPa). How do we know that? Well, we can use [`inputs`](@ref) to know:

```@example usepkg
inputs(Fvcb())
```

```@example usepkg
inputs(Medlyn(0.03, 12.0))
```

Note that some variables are common inputs between models. This is why we prefer using [`to_initialise`](@ref) instead. [`to_initialise`](@ref) is a clever little function that gives unique input variables and remove the input variables that are outputs of other models (no need to input if they are simulated):

```@example usepkg
to_initialise(Fvcb(),Medlyn(0.03, 12.0))
```

Or directly on a component model after instantiation:

```@example usepkg
leaf = ModelList(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0)
)

to_initialise(leaf)
```

We can also use [`is_initialised`](@ref) to know if a component is correctly initialised:

```@example usepkg
is_initialised(leaf)
```

And then we can initialise the component model status using [`init_status!`](@ref):

```@example usepkg
init_status!(leaf, Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = 1.2)
```

And check again if it worked:

```@example usepkg
is_initialised(leaf)
```

The most straightforward way of initialising a component models is by giving the initialisations as keyword arguments directly during instantiation:

```@example usepkg
ModelList(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = 0.82
)
```

Our component models structure is now fully parameterized and initialized for a simulation!

## Simulation

### Simulation of processes

Simulating a component is rather simple, simply use the function with the name of the process you want to simulate:

- [`stomatal_conductance`](@ref) for the stomatal conductance
- [`photosynthesis`](@ref) for the photosynthesis
- [`energy_balance`](@ref) for the energy balance

!!! note
    All functions exist in a non-mutating form and a mutating form. Just add `!` at the end of the name of the function to use the mutating form and speed! 🚀

The call to the function is the same whatever the model you choose for simulating the process. This is some magic allowed by Julia! A call to a function is made as follows:

```julia
stomatal_conductance(component_models,meteo)
photosynthesis(component_models,meteo)
energy_balance(component_models,meteo)
```

The first argument is the component models, and the second defines the micro-climatic conditions (more details below in [Climate forcing](@ref)).

### Example simulation

For example we can simulate the [`photosynthesis`](@ref) like so:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = ModelList(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = meteo.VPD
)

photosynthesis!(leaf, meteo)
```

Very simple right? There are functions for [`energy_balance!`](@ref) and [`stomatal_conductance!`](@ref) too.

### Functions forms

Each function exists on three forms, *e.g.* [`energy_balance`](@ref) has:

- `energy_balance`: the generic function that makes a copy of the components model and return the status (not very efficient but easy to use)
- `energy_balance!`: the faster generic function. But we need to extract the outputs from the component models after the simulation (note the `!` at the end of the name)
- `energy_balance!_`: the internal implementation with a method for each model. PlantBiophysics then uses multiple dispatch to choose the right method based on the model type. If you don't plan to make your own models, you'll never have to use it 🙂

If you want to implement your own models, please read this section in full first, and then [Model implementation](@ref model_implementation_page).

!!! note
    The functions can be applied on a components model only if there is a model parameterized for its corresponding process.

## Climate forcing

To make a simulation, we usually need the climatic/meteorological conditions measured close to the object or component. They are given as the second argument of the simulation functions shown before.

The package provide its own data structures to declare those conditions, and to pre-compute other required variables. The most basic data structure is a type called [`Atmosphere`](@ref), which defines the conditions for a steady-state, *i.e.* the conditions are considered at equilibrium. Another structure is available to define different consecutive time-steps: [`Weather`](@ref).

The mandatory variables to provide for an [`Atmosphere`](@ref) are: `T` (air temperature in °C), `Rh` (relative humidity, 0-1), `Wind` (the wind speed in m s-1) and `P` (the air pressure in kPa). We can declare such conditions like so:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
```

More details are available from the [dedicated section](@ref microclimate_page).

### Outputs

The `status` field of a component model (*e.g.* [`ModelList`](@ref)) is used to keep track of the variables values during the simulation. We can extract the simulation outputs of a component models using [`status`](@ref).

!!! note
    Getting the status is only useful when using the mutating version of the function (*e.g.* [`energy_balance!`](@ref)), as the non-mutating version returns the output directly.

The status can either be a [MutableNamedTuple](https://github.com/MasonProtter/MutableNamedTuples.jl) (works like a tuple) if simulating only one time-step, or a vector of MutableNamedTuples if several.

Let's look at the status of our previous simulated leaf:

```@setup usepkg
status(leaf)
```

We can extract the value of one variable using the `status` function, *e.g.* for the assimilation:

```@example usepkg
status(leaf)
```

Or similarly using the dot syntax:

```@example usepkg
leaf.status.A
```

Or much simpler (and recommended):

```@example usepkg
leaf[:A]
```

Another simple way to get the results is to transform the outputs into a `DataFrame`:

```@example usepkg
DataFrame(leaf)
```

!!! note
    The output from `DataFrame` is adapted to the kind of simulation you did: one row per time-steps, and per component models if you simulated several.

## List of models

As presented above, each process is simulated using a particular model. A model can work either independently or in conjunction with other models. For example a stomatal conductance model is often associated with a photosynthesis model, *i.e.* it is called from the photosynthesis model.

Several models are provided in this package, and the user can also add new models by following the instructions in the corresponding section.

The models included in the package are listed in their own section, *i.e.* for photosynthesis, you can look at [this section](@ref photosynthesis_page).
