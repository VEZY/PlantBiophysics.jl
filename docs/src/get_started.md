# Getting started

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

If you want to implement your own models, please read the [Concepts and design](@ref) section first.

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

The first argument to the function is what we call a component model ([`AbstractComponentModel`](@ref)). A component model is a data structure that lists in its fields the processes simulated for a component, and the chosen model and its associated parameter values.

The model is chosen by using a particular type of model for a process field of a component model. The type of the model helps Julia know which method it should use for simulating the process. But this is complicated technical gibberish for something quite simple. Let's use an example instead!

The most sounding example of a component model is [`LeafModels`](@ref). It is designed to hold all processes simulated for a photosynthetic organ, or at least for a leaf.

A [`LeafModels`](@ref) has five fields:

```@example
fieldnames(LeafModels)
```

The first four are for defining models used to simulate the associated processes, and the fifth (`status`) helps keeping track of simulated variables (they can be modified after a simulation).

Let's instantiate a [`LeafModels`](@ref) with some models. If we want to simulate the photosynthesis with the model of Farquhar et al. (1980) and the stomatal conductance with the model of Medlyn et al. (2011), we would use `Fvcb()` and `Medlyn` respectively, as follows:

```@example
LeafModels(photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0))
```

We can instantiate a [`LeafModels`](@ref) without choosing a model for all processes. In our example the `interception` and `energy` are not provided, so they will have the value `missing` by default in our leaf, meaning they cannot be simulated.

Now if we simulate the photosynthesis, we need to provide the values for input variables. This is done as follows:

```@example
LeafModels(photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = 0.82)
```

You can see that some variables were given as keyword arguments (`Tₗ = 25.0`, `PPFD = 1000.0`, `Cₛ = 400.0`, `Dₗ = 0.82`). This is a convenience to set up initialization values for some variables required by models. For example here `PPFD` and `Tₗ` are needed for the `Fvcb` model, `Dₗ` is needed for `Medlyn`, and `Cₛ` for both.

To know which variables you need to initialize for a simulation, use the `to_initialise()` function on one or several model instances. For example in our case we use the `Fvcb` and `Medlyn` models, so we would do:

```@example
to_initialise(Fvcb(),Medlyn(0.03, 12.0))
```

### Climate forcing

To make a simulation, we first need the climatic/meteorological conditions measured close to the object or component. The package provide its own data structure to declare those conditions, while pre-computing some variables. This data structure is a type called [`Atmosphere`](@ref).

The mandatory variables to provide are: `T` (air temperature in °C), `Rh` (relative humidity, 0-1), `Wind` (the windspeed in m s-1) and `P` (the air pressure in kPa).

We can declare such conditions using [`Atmosphere`](@ref) such as:

```@example
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
```

The [`Atmosphere`](@ref) also computes other variables based on the provided conditions, such as the vapor pressure deficit (VPD) or the air density (ρ). You can also provide them as inputs if necessary. For example if you need another way of computing the VPD, you can provide it as follows:

```@example
Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65, VPD = 0.82)
```

To access the values of the variables in `meteo`, use the dot syntax. For example if we need the vapor pressure at saturation, we would do as follows:

```@example
meteo.eₛ
```

See the documentation of the function if you need more information about the variables.

### Example simulation

Put a simulation of e.g. energy_balance here.

## Models and structures

### Stomatal conductance

The stomatal conductance (`Gₛ`) can be simulated using the [`gs`](@ref) function. Several models are available to simulate it:

- [`Medlyn`](@ref): an implementation of the Medlyn et al. (2011) model
- [`ConstantGs`](@ref): a model to force a constant value for `Gₛ`

### Photosynthesis

The photosynthesis can be simulated using the [`photosynthesis`](@ref) function. Several models are available to simulate it:

- [`Fvcb`](@ref): an implementation of the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981) using the analytical resolution
- [`FvcbIter`](@ref): the same model but implemented using an iterative computation over Cᵢ
- [`ConstantA`](@ref): a model to set the photosynthesis to a constant value (mainly for testing)

You can choose which model you use by passing a component with an assimilation model set to one of the structs above. We will show some examples in the end of this paragraphh.

For example, you can simulate a constant assimilation of a leaf using the following code:

```@example
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = LeafModels(photosynthesis = ConstantA(25.0),
            stomatal_conductance = ConstantGs(0.03,0.001),
            Tₗ = 25.0, PPFD = 1000.0, Gbc = 0.67, Dₗ = meteo.VPD)

assimilation!(leaf,meteo,Constants())
```

### Energy balance

The simulation of the energy balance of a component is the most integrative process of the package because it is (potentially) coupled with the conductance and assimilation models if any.

To simulate the energy balance of a component, we use the [`energy_balance`](@ref) function.
