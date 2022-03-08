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
    Of course we could describe the plant at a coarser (*e.g.* axis) or finer (*e.g.* growth units) scale, but this is not relevant here.

PlantBiophysics doesn't implement components *per se*, because it is more the job of other packages. However, PlantBiophysics provides components models.

!!! tip
    [MultiScaleTreeGraph](https://vezy.github.io/MultiScaleTreeGraph.jl/stable/) implements a way of describing a plant as a tree data-structure. PlantBiophysics even provides methods for computing processes over such data.

### What are component models

Components models are structures that define which models are used to simulate the biophysical processes of a component.

PlantBiophysics provides the [`LeafModels`](@ref) and the more generic [`ComponentModels`](@ref) component models. The first one is designed to represent a photosynthetic organ such as a leaf, and the second for a more generic organ such as wood for example.

!!! tip
    These are provided as defaults, but you can easily define your own component models if you want, and then implement the models for each of its processes.

### Processes

A process in this package defines a biological or a physical phenomena. For example [`LeafModels`](@ref) implements four processes:

- the radiation interception
- the energy balance
- the photosynthesis
- and the stomatal conductance

We can list the processes of a component model using `fieldnames`:

```@example usepkg
fieldnames(LeafModels)
```

We can see there is a fifth field along the processes called `:status`. This one is mandatory for all component models, and is used to initialise the simulated variables and keep track of their values during the simulation.

These processes can be simulated using different models.

## Models

### What is a model?

A process is simulated using a particular implementation of a model. The user can choose which model is used to simulate a process when instantiating the component models.

You can see the list of available models for each processes in the [Generic models](@ref) section.

Each model is implemented using a structure that lists the parameters of the model. For example PlantBiophysics provides the [`Fvcb`](@ref) structure for the implementation of the Farquhar–von Caemmerer–Berry model for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981), and the [`Medlyn`](@ref) structure for the model of Medlyn et al. (2011).

### Parameterization

To simulate a process for a component models we need to parameterize it with a given model.

Let's instantiate a [`LeafModels`](@ref) with the model of Farquhar et al. (1980) for the photosynthesis and the model of Medlyn et al. (2011) for the stomatal conductance. THe corresponding structures are `Fvcb()` and `Medlyn()` respectively.

```@example usepkg
LeafModels(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03, 12.0))
```

!!! tip
    We see that we only instantiated the [`LeafModels`](@ref) for the photosynthesis and stomatal conductance processes. What about the radiation interception and the energy balance? Well there is no need to give models if we have no intention to simulate them.

OK so what happened here? We provided a instance of models to the processes. But why Fvcb has no parameters and Medlyn has two? Well, models usually provide default values for their parameter. We can see that the `Fvcb` model as actually a lot of parameters:

```@example usepkg
fieldnames(Fvcb)
```

We just used the defaults. But if we need to change the values of some parameters, we can give them as keyword arguments:

```@example usepkg
Fvcb(VcMaxRef = 250.0, JMaxRef = 300.0, RdRef = 0.5)
```

Perfect! Now is that all we need for making a simulation? Well, usually no. Models need parameters, but also input variables.

### Model initialisation

Remember that our component models have a field named `:status`? Well this status is actually used to hold all inputs and outputs of our models. For example the [`Fvcb`](@ref) model needs the leaf temperature (`Tₗ`, Celsius degree), the Photosynthetic Photon Flux Density (`PPFD`, ``μmol\\ m^{-2}\\ s^{-1}``) and the CO₂ concentration at the leaf surface (`Cₛ`, ppm) to run. The [`Medlyn`](@ref) model needs the assimilation (`A`, ``μmol\\ m^{-2}\\ s^{-1}``), the CO₂ concentration at the leaf surface (`Cₛ`, ppm) and the vapour pressure difference between the surface and the saturated air vapour pressure (`Dₗ`, kPa). How do we know that? Well, we can use [`inputs`](@ref) to know:

```@example usepkg
inputs(Fvcb())
```

Or better, we can use [`to_initialise`](@ref) on one or several model instances, or directly on a component model (*e.g.* [`LeafModels`](@ref)). For example in our case we use the `Fvcb` and `Medlyn` models, so we would do:

```@example usepkg
to_initialise(Fvcb(),Medlyn(0.03, 12.0))
```

Or directly on a component model after instantiation:

```@example usepkg
leaf = LeafModels(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0)
)

to_initialise(leaf)
```

[`to_initialise`](@ref) is a clever little function that gesses which variables need initialisation considering that inputs of some models will be simulated by others.

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
LeafModels(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = 0.82
)
```

Our component models structure is now fully parameterized and initialized for a simulation!

## Simulation

### Simulation of processes

Simulating a component is rather simple, simply use the function that has the name of the process to simulate it:

- [`gs`](@ref) for the stomatal conductance
- [`photosynthesis`](@ref) for the photosynthesis
- [`energy_balance`](@ref) for the energy balance

The call to the function is the same whatever the model you choose for simulating the process. This is some magic allowed by Julia! A call to a function is made as follows:

```julia
gs(component,meteo)
photosynthesis!(component,meteo)
energy_balance!(component,meteo)
```

The first argument is the component models, and the second defines the micro-climatic conditions (more details below in [Climate forcing](@ref)).

### Example simulation

For example we can simulate the [`photosynthesis`](@ref) like so:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = LeafModels(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = meteo.VPD
)

photosynthesis(leaf, meteo)
```

Very simple right? There are functions for [`energy_balance`](@ref) and [`gs`](@ref) too.

### Functions forms

Each function exists on three forms, *e.g.* [`energy_balance`](@ref) has:

- `energy_balance`: the generic function that makes a copy of the components model and return the status (not very efficient but easy to use)
- `energy_balance!`: the faster generic function. But we need to extract the outputs from the components models after the simulation (note the `!` at the end of the name)
- `energy_balance!_`: the internal implementation with a method for each model. PlantBiophysics then uses multiple dispatch to choose the right method based on the model type. If you don't plan to make your own models, you'll never have to use it 🙂

If you want to implement your own models, please read this section in full first, and then [Model implementation](@ref model_implementation_page).

### Climate forcing

To make a simulation, we usually need the climatic/meteorological conditions measured close to the object or component. They are given as the second argument of the simulation functions shown before.

The package provide its own data structure to declare those conditions, and to pre-compute other required variables. This data structure is a type called [`Atmosphere`](@ref).

The mandatory variables to provide are: `T` (air temperature in °C), `Rh` (relative humidity, 0-1), `Wind` (the wind speed in m s-1) and `P` (the air pressure in kPa).

We can declare such conditions using [`Atmosphere`](@ref) such as:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
```

The [`Atmosphere`](@ref) also computes other variables based on the provided conditions, such as the vapor pressure deficit (VPD) or the air density (ρ). You can also provide those variables as inputs if necessary. For example if you need another way of computing the VPD, you can provide it as follows:

```@example usepkg
Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65, VPD = 0.82)
```

To access the values of the variables in after instantiation, we can use the dot syntax. For example if we need the vapor pressure at saturation, we would do as follows:

```@example usepkg
meteo.eₛ
```

See the documentation of the function if you need more information about the variables: [`Atmosphere`](@ref).

If you want to simulate several time-steps with varying conditions, you can do so by using [`Weather`](@ref) instead of [`Atmosphere`](@ref).

[`Weather`](@ref) is just an array of [`Atmosphere`](@ref) along with some optional metadata. For example for three time-steps, we can declare it like so:

```@example usepkg
w = Weather(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ],
    (site = "Montpellier",
    other_info = "another crucial metadata")
)
```

As you see the first argument is an array of [`Atmosphere`](@ref), and the second is a named tuple of optional metadata such as the site or whatever you think is important.

A [`Weather`](@ref) can also be declared from a DataFrame, provided each row is an observation from a time-step, and each column is a variable needed for [`Atmosphere`](@ref) (see the help of [`Atmosphere`](@ref) for more details on the possible variables and their units).

Here's an example of using a DataFrame as input:

```@example usepkg
using CSV, DataFrames
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","meteo.csv")
df = CSV.read(file, DataFrame; header=5, datarow = 6)
# Select and rename the variables:
select!(df, :date, :VPD, :temperature => :T, :relativeHumidity => :Rh, :wind => :Wind, :atmosphereCO2_ppm => :Cₐ)
df[!,:duration] .= 1800 # Add the time-step duration, 30min

# Make the weather, and add some metadata:
Weather(df, (site = "Aquiares", file = file))
```

One can also directly import the Weather from an Archimed-formatted meteorology file (a csv file optionally enriched with some metadata). In this case, the user can rename and transform the variables from the file to match the names and units needed in PlantBiophysics using a [`DataFrame.jl`](https://dataframes.juliadata.org/stable/)-alike syntax:

```@example usepkg
using Dates

meteo = read_weather(
    joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","meteo.csv"),
    :temperature => :T,
    :relativeHumidity => (x -> x ./100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)
```

### Outputs

The `status` field of a component model (*e.g.* [`LeafModels`](@ref)) is used to keep track of the variables values during the simulation. We can extract the simulation outputs of a component models using [`status`](@ref), *e.g.*:

!!! note
    Getting the status is only useful when using the mutating version of the function (*e.g.* [`energy_balance`](@ref)), as the non-mutating version returns the output directly.

The status can either be a MutableNamedTuple (works like a tuple) if simulating only one time-step, or a vector of MutableNamedTuples if several.

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
    The output from `DataFrame` is adapted to the kind of simulation you did: one or several component over one or several time-steps.

## List of models

As presented above, each process is simulated using a particular model. A model can work either independently or in conjunction with other models. For example a stomatal conductance model is often associated with a photosynthesis model. *i.e.*, it is called from the photosynthesis model.

Several models are provided in this package, and the user can also add new models by following the instructions in the corresponding section.

The models included in the package are listed below.

### Stomatal conductance

The stomatal conductance (`Gₛ`) can be simulated using the [`gs`](@ref) function. Several models are available to simulate it:

- [`Medlyn`](@ref): an implementation of the Medlyn et al. (2011) model
- [`ConstantGs`](@ref): a model to force a constant value for `Gₛ`

### Photosynthesis

The photosynthesis can be simulated using the [`photosynthesis`](@ref) function. Several models are available to simulate it:

- [`Fvcb`](@ref): an implementation of the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981) using the analytical resolution
- [`FvcbIter`](@ref): the same model but implemented using an iterative computation over Cᵢ
- [`FvcbRaw`](@ref): the same model but without the coupling with the stomatal conductance, *i.e.* as presented in the original paper. This version needs Cᵢ as input.
- [`ConstantA`](@ref): a model to set the photosynthesis to a constant value (mainly for testing)

You can choose which model you use by passing a component with an assimilation model set to one of the `structs` above. We will show some examples in the end of this paragraph.

For example, you can simulate a constant assimilation of a leaf using the following code:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = LeafModels(
    photosynthesis = ConstantA(25.0),
    stomatal_conductance = ConstantGs(0.03,0.1),
    Cₛ = 380.0
)

photosynthesis(leaf,meteo)
```

### Energy balance

The simulation of the energy balance of a component is the most integrative process of the package because it is (potentially) coupled with the conductance and assimilation models if any.

To simulate the energy balance of a component, we use the [`energy_balance!`](@ref) function. Only one model is implemented yet, the one presented in Monteith and Unsworth (2013). The structure is called [`Monteith`](@ref), and is only used for photosynthetic organs. Further implementations will come in the future.
