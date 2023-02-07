# Implement a new component models

```@setup usepkg
using PlantSimEngine, PlantBiophysics, PlantMeteo
PlantSimEngine.@process growth
```

## Introduction

`PlantBiophysics.jl` is based on `PlantSimEngine.jl`, a package designed to make the implementation of new processes and models easy and fast. Let's learn about how to implement your own process with a simple example: a growth model.

## Implement a new process

To implement a new process, we need to define the generic methods used for its simulation for:

- one or several time-steps
- one or several objects
- an MTG from MultiScaleTreeGraph

...and all the above with a mutating function and a non-mutating one.

This is a lot of work! But fortunately PlantSimEngine provides a macro to generate all of the above: `gen_process_methods`.

This macro takes only one argument: the name of the process.

So for example all the photosynthesis methods are created using just this tiny line of code:

```julia
using PlantSimEngine
@process photosynthesis
```

So for example if we want to simulate the growth of a plant, we could add a new process called `growth`. To create the generic functions to simulate the `growth` we would do:

```julia
using PlantSimEngine
@process growth
```

And that's it! You created a new process called `growth`, with the following functions:

- `growth!`: the mutating function
- `growth`: the non-mutating function
- `growth!_`: the function that actually make the computation. You'll have to implement methods for each model you need, else it will not work.

Now users can call `growth!` and `growth` on any number of time steps or objects, even on MTGs, and PlantSimEngine will handle everything. 

`@process` also created an abstract struct called `AbstractGrowthModel` that is used as a supertype for our model structs. This helps PlantSimEngine identify which process a model is implemented for.

But first, we need at least one model to simulate it.

!!! note
    You still can use the processes and models defined in PlantBiophysics.

## Implement a new model for the process

To better understand how models are implemented, you can read the detailed instructions from the [previous section](@ref model_implementation_page). But for the sake of completeness, we'll implement a growth model here.

This growth model uses the assimilation computed using the coupled energy balance process. Then it removes the maintenance respiration and the growth respiration from that source of carbon, and increments the leaf biomass by the remaining carbon offer.

Let's implement this model below:

```@example usepkg
# Make the struct to hold the parameters:
"""
    DummyGrowth(Rm_factor, Rg_cost)
    DummyGrowth(;Rm_factor = 0.5, Rg_cost = 1.2)

Computes the leaf biomass growth of a plant.

# Arguments

- `Rm_factor`: the fraction of assimilation that goes into maintenance respiration
- `Rg_cost`: the cost of growth maintenance, in gram of carbon biomass per gram of assimilate
"""
struct DummyGrowth{T} <: AbstractGrowthModel
    Rm_factor::T
    Rg_cost::T
end

# Note that DummyGrowth is a subtype of AbstractGrowthModel, this is important

# Instantiate the struct with default values + kwargs:
function DummyGrowth(;Rm_factor = 0.5, Rg_cost = 1.2)
    DummyGrowth(promote(Rm_factor,Rg_cost)...)
end

# Define methods for inputs_ and outputs_ functions for our model:
function PlantSimEngine.inputs_(::DummyGrowth)
    (A=-999.99,)
end

function PlantSimEngine.outputs_(::DummyGrowth)
    (Rm=-999.99, Rg=-999.99, leaf_allocation=-999.99, leaf_biomass=0.0)
end

# Tells Julia what is the type of elements (optional):
Base.eltype(x::DummyGrowth{T}) where {T} = T

# Implement the growth model:
function growth!_(::DummyGrowth, models, status, meteo, constants, extra)

    # Compute the energy balance of the plant, coupled to the photosynthesis model:
    PlantBiophysics.run!(models.energy_balance, models, status, meteo, constants, extra)
    # Here we expect the assimilation of the plant, which is the source for Carbon

    # The maintenance respiration is simply a factor of the assimilation:
    status.Rm = status.A * models.growth.Rm_factor

    # Let's say that all carbon is allocated to the leaves:
    status.leaf_allocation = status.A - status.Rm

    # And that this carbon is allocated with a cost (growth respiration Rg):
    status.Rg = 1 - (status.leaf_allocation / models.growth.Rg_cost)

    status.leaf_biomass = status.leaf_biomass + status.leaf_allocation - status.Rg
end
```

Now we can make a simulation as usual:

```@example usepkg
using PlantMeteo
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

leaf = ModelList(
        energy_balance = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        growth = DummyGrowth(),
        status = (Rₛ = 13.747, sky_fraction = 1.0, PPFD = 1500.0, d = 0.03)
    )

growth!(leaf,meteo)

leaf[:leaf_biomass] # biomass in gC
```

We can also start the simulation later when the plant already has some biomass by initializing the `leaf_biomass`:

```@example usepkg
using PlantMeteo
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

leaf = ModelList(
        energy_balance = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        growth = DummyGrowth(),
        status = (Rₛ = 13.747, sky_fraction = 1.0, PPFD = 1500.0, d = 0.03, leaf_biomass = 2400.0)
    )

growth!(leaf,meteo)

leaf[:leaf_biomass] # biomass in gC
```
