# Getting started
## Introduction

The package is designed to ease the computations of biophysical processes in plants and other objects. It is part of the [Archimed platform](https://archimed-platform.github.io/), so it shares the same ontology (same concepts and terms).

This package is designed to simulate four different processes:

- photosynthesis
- stomatal conductance
- energy balance
- light interception (no models at the moment, but coming soon!)

These processes can be simulated using different models included in the package, or provided by the user. Each process is defined by a generic function, and an abstract struct (see [Concepts and design](@ref)).

The structs are used for two purposes: to hold the parameter values of a model, and to dispatch to the right method when calling the functions. They are generally named after the model they implement.

If you don't plan to implement your own model, you just have to learn about the different structures you can use, and which functions you can use. This is what we describe in this section.

If you want to implement your own models, please read the [Concepts and design](@ref) section first.

## Using a model

In this package, each process can be simulated using a function:

- [`gs`](@ref) for the stomatal conductance
- [`photosynthesis`](@ref) for the photosynthesis
- [`energy_balance`](@ref) for the energy balance

The call to the function is the same whatever the actual models used to simulate the process. This is some magic allowed by Julia!

The first argument to those functions is what we call a component model ([`AbstractComponentModel`](@ref)). A component model is a data structure that lists the processes simulated for a component as fields, and the models and its associated parameter values.

The model is then chosen by using a particular type of model for a process field of a component model. The type of the model helps Julia know which method it should use for simulating the process. But this is complicated technical gibberish for something quite simple. Let's use an example instead!

The most sounding example of a component model is [`Leaf`](@ref). It is designed to hold all processes simulated for a photosynthetic organ, or at least for a leaf.

A [`Leaf`](@ref) has five fields:

```@example
fieldnames(Leaf)
```

The first four are for defining models used to simulate the associated processes, and the fifth (`status`) helps keeping track of simulated variables (they can be modified after a simulation).

Let's instantiate a [`Leaf`](@ref) with some models. If we want to simulate the photosynthesis with the model of Farquhar et al. (1980), we would use `Fvcb()`, and the stomatal conductance with the model of Medlyn et al. (2011) we woul use `Medlyn`, such as follows:

```@example
Leaf(photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = 0.82)
```

We can instantiate a [`Leaf`](@ref) without requesting a model for all fields. In our example the `interception`, `energy` are not provided, so they will have the value `missing` by default in our leaf.

You can see that some variables were given as keyword arguments (`Tₗ = 25.0`, `PPFD = 1000.0`, `Cₛ = 400.0`, `Dₗ = 0.82`). This is a convenience to set up initialization values for some variables required in models. For example here `PPFD` and `Tₗ` are needed for the `Fvcb` model, `Dₗ` is needed for `Medlyn`, and `Cₛ` for both.

## Models and structures

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

### Stomatal conductance

The stomatal conductance (`Gₛ`) can be simulated using the [`gs`](@ref) function. Several models are available to simulate it:

- [`Medlyn`](@ref): an implementation of the Medlyn et al. (2011) model
- [`ConstantGs`](@ref): a model to force a constant value for `Gₛ`

### Photosynthesis

The photosynthesis can be simulated using the [`photosynthesis!`](@ref) function. Several models are available to simulate it:

- [`Fvcb`](@ref): an implementation of the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981) using the analytical resolution
- [`FvcbIter`](@ref): the same model but implemented using an iterative computation over Cᵢ
- [`ConstantA`](@ref): a model to set the photosynthesis to a constant value (mainly for testing)

You can choose which model you use by passing a component with an assimilation model set to one of the structs above. We will show some examples in the end of this paragraphh.

For example, you can simulate a constant assimilation of a leaf using the following code:

```@example
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = Leaf(photosynthesis = ConstantA(25.0),
            stomatal_conductance = ConstantGs(0.03,0.001),
            Tₗ = 25.0, PPFD = 1000.0, Gbc = 0.67, Dₗ = meteo.VPD)

assimilation!(leaf,meteo,Constants())
```

### Energy balance

The simulation of the energy balance of a component is the most integrative process of the package because it is (potentially) coupled with the conductance and assimilation models if any.

To simulate the energy balance of a component, we use the [`energy_balance`](@ref) function.
