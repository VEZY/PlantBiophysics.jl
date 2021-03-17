# Getting started

```@setup usepkg
using PlantBiophysics
leaf = LeafModels(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03, 12.0))
```

## TL;DR

Simulate the leaf energy balance, photosynthesis and stomatal conductance at once using the following code:

```@example usepkg
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

leaf = LeafModels(energy = Monteith(),
            photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            Rₛ = 13.747, skyFraction = 1.0, PPFD = 1500.0, d = 0.03)

energy_balance(leaf,meteo)
```

## Introduction

The package is designed to ease the computations of biophysical processes in plants and other objects. It is part of the [Archimed platform](https://archimed-platform.github.io/), so it shares the same ontology (same concepts and terms).

This package is designed to simulate four different processes:

- photosynthesis
- stomatal conductance
- energy balance
- light interception (no models at the moment, but coming soon!)

These processes can be simulated using different models included in the package, or provided by the user. Each process has its associated generic function and abstract struct (see [Concepts and design](@ref)).

Then, the models are chosen by using a concrete structure that serves two purposes: holding the parameter values of the model, and dispatch to the right method when calling the generic function. They are generally named after the model they implement.

If you don't plan to implement your own model, you just have to learn about the generic functions and the different models implemented to simulate the processes. This is what we describe in this section.

If you want to implement your own models, please read the [Concepts and design](@ref) section first, and then [Model implementation](@ref model_implementation_page).

## Using a model

In this package, each process can be simulated using a function:

- [`gs`](@ref) for the stomatal conductance
- [`photosynthesis`](@ref) for the photosynthesis
- [`energy_balance`](@ref) for the energy balance

The call to the function is the same whatever the model you chose for simulating the process. This is some magic allowed by Julia! A call to a function is as follows:

```julia
gs(component,meteo)
photosynthesis(component,meteo)
energy_balance(component,meteo)
```

We describe the two arguments below.

### Component model

The first argument to the function is what we call a component model ([`AbstractComponentModel`](@ref)). A component model is a data structure that lists in its fields the processes simulated for a component, and the associated model and parameter values.

The model is chosen by using a particular type of model for a field of the component model. The type (in the programmatic sense) of the model helps Julia know which method it should use for simulating the process. But this is complicated technical gibberish for something quite simple. Let's use an example instead!

The most sounding example of a component model is [`LeafModels`](@ref). It is designed to hold all processes simulated for a photosynthetic organ, or at least for a leaf.

A [`LeafModels`](@ref) has five fields:

```@example usepkg
fieldnames(LeafModels)
```

The first four are for defining models used to simulate the associated processes, and the fifth (`status`) helps keeping track of the state of simulated variables, because they can be modified by a simulation.

Let's instantiate a [`LeafModels`](@ref) with some models. If we want to simulate the photosynthesis with the model of Farquhar et al. (1980) and the stomatal conductance with the model of Medlyn et al. (2011), we would use `Fvcb()` and `Medlyn` respectively, as follows:

```@example usepkg
LeafModels(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03, 12.0))
```

We can instantiate a [`LeafModels`](@ref) without choosing a model for all processes. In our example above we don't provide any model for the `interception` and `energy` processes, so they will have the default value `missing` in our leaf, meaning they cannot be simulated.

Some models require some variables as input values. For example if we want to simulate the leaf photosynthesis using the `Fvcb` model, we need the leaf temperature, the PPFD (Photosynthetic Photon Flux Density) and the CO₂ concentration at the leaf surface. The values for these variables are given as follows:

```@example usepkg
LeafModels(photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = 0.82)
```

They are given as keyword arguments (`Tₗ = 25.0`, `PPFD = 1000.0`, `Cₛ = 400.0`, `Dₗ = 0.82`). This is a convenience to set up initialization values for some variables required by models. We already know that `PPFD`, `Cₛ` and `Tₗ` are needed for the `Fvcb` model. And `Dₗ` is needed for the `Medlyn` model ( and `Cₛ` too).

To know which variables you need to initialize for a simulation, use the [`to_initialise`](@ref) function on one or several model instances, or directly on a component model (*e.g.* [`LeafModels`](@ref)). For example in our case we use the `Fvcb` and `Medlyn` models, so we would do:

```@example usepkg
to_initialise(Fvcb(),Medlyn(0.03, 12.0))
```

Or directly on a component model after instantiation:

```@example usepkg
leaf = LeafModels(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03, 12.0))
to_initialise(leaf)
```

You can also use [`is_initialised`](@ref) to know if a component is sufficiently initialized:

```@example usepkg
is_initialised(leaf)
```

And then you can initialize the component model status using [`init_status!`](@ref):

```@example usepkg
init_status!(leaf, Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = 1.2)
```

And check again if it worked:

```@example usepkg
is_initialised(leaf)
```

Yes, it did!

Both [`to_initialise`](@ref) and [`is_initialised`](@ref) search for common input variables among all models used. Then, they compare with the outputs of the models, and if one variable is needed as input but provided as output of another model, the variable is not considered for initialization because it is thought that the user will simulate these variables.

### Climate forcing

To make a simulation, we most often need the climatic/meteorological conditions measured close to the object or component. They are given as the second argument of the process functions shown before.

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

To access the values of the variables in `meteo`, use the dot syntax. For example if we need the vapor pressure at saturation, we would do as follows:

```@example usepkg
meteo.eₛ
```

See the documentation of the function if you need more information about the variables.

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
- [`ConstantA`](@ref): a model to set the photosynthesis to a constant value (mainly for testing)

You can choose which model you use by passing a component with an assimilation model set to one of the `structs` above. We will show some examples in the end of this paragraph.

For example, you can simulate a constant assimilation of a leaf using the following code:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = LeafModels(photosynthesis = ConstantA(25.0),
                stomatal_conductance = ConstantGs(0.03,0.1),
                Cₛ = 380.0)

photosynthesis(leaf,meteo)
```

### Energy balance

The simulation of the energy balance of a component is the most integrative process of the package because it is (potentially) coupled with the conductance and assimilation models if any.

To simulate the energy balance of a component, we use the [`energy_balance`](@ref) function. Only one model is implemented yet, the one presented in Monteith and Unsworth (2013). The structure is called [`Monteith`](@ref), and is only used for photosynthetic organs. Further implementations will come in the future.
