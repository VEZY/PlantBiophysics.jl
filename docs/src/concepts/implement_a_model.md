# [Model implementation in 5 minutes](@id model_implementation_page)

## Introduction

`PlantBiophysics.jl` was designed to make new model implementation very simple. So let's learn about how to implement you own model with a simple example: implementing a new stomatal conductance model.

## Inspiration

If you want to implement a new model, the best way to do it is to start from another implementation.

So for a photosynthesis model, I advise you to look at the implementation of the FvCB model in this Julia file: [src/photosynthesis/FvCB.jl](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/photosynthesis/FvCB.jl).

For an energy balance model you can look at the implementation of the Monteith model in [src/energy/Monteith.jl](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/energy/Monteith.jl), and for a stomatal conductance model in [src/conductances/stomatal/medlyn.jl](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/conductances/stomatal/medlyn.jl).

## Requirements

In those files, you'll see that in order to implement a new model you'll need to implement:

- a structure, used to hold the parameter values and to dispatch to the right method
- the actual model, developed as a method for the process it simulates
- some helper functions used by the package and/or the users

Let's take a simple example with a new model for the stomatal conductance: the Ball and Berry model.

## Example: the Ball and Berry model

### The structure

The first thing to do is to implement a structure for your model.

The purpose of the structure is two-fold:

- hold the parameter values
- dispatch to the right method when calling the process function

Let's take the [stomatal conductance model from Medlyn et al. (2011)](https://github.com/VEZY/PlantBiophysics.jl/blob/3fccb2cecf03cc3987ad037a8994016b0527546f/src/conductances/stomatal/medlyn.jl#L37) as a starting point. The structure of the model (or type) is defined as follows:

```julia
struct Medlyn{T} <: AbstractGsModel
    g0::T
    g1::T
    gs_min::T
end
```

The first line defines the name of the model (`Medlyn`), with the types that will be used for the parameters. Then it defines the structure as a subtype of [`AbstractGsModel`](@ref). This step is very important as it tells to the package what kind of model it is. In this case, it is a stomatal conductance model, that's why we use [`AbstractGsModel`](@ref). We would use [`AbstractAModel`](@ref) instead for a photosynthesis model, and [`AbstractEnergyModel`](@ref) for an energy balance model.

Then comes the parameters names, and their types. The type of the parameters is always forced to be of the same type in our example. This is done using the `T` notation as follows:

- we say that our structure `Medlyn` is a parameterized struct by putting `T` in between brackets after the name of the struct
- We pur `::T` after our parameter names in the struct. This way Julia knows that all parameters must be of type T.

The `T` is completely free, you can use any other letter or word instead. If you have parameters that you know will be of different types, you can either force their type, or make them parameterizable too using another letter, *e.g.*:

```julia
struct YourStruct{T,S} <: AbstractGsModel
    g0::T
    g1::T
    gs_min::T
    integer_param::S
end
```

Parameterized types are very useful because they let the user choose the type of the parameters, but still help Julia make the computations fast.

But why not forcing the type such as the following:

```julia
struct YourStruct <: AbstractGsModel
    g0::Float64
    g1::Float64
    gs_min::Float64
    integer_param::Int
end
```

Well, you can do that. But you'll lose a lot of the magic Julia has to offer this way.

For example a user could use the `Particles` type from [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl) to make automatic uncertainty propagation, and this is only possible if the type is parameterizable.

So let's implement a new structure for our stomatal conductance model:

```julia
struct BandB <: AbstractGsModel
    g0::T
    g1::T
    gs_min::T
end
```

Well, the only thing we had to change relative to the one from Medlyn is the name, easy! This is because both models share the same parameters.

### The method

```julia
function gs_closure(leaf::LeafModels{I,E,A,<:BandB,S},meteo) where {I,E,A,S}
    leaf.stomatal_conductance.g1 * meteo.Rh / leaf.status.Cₛ
end
```

-> talk about why we use gs_closure instead of gs

### The utility functions

```julia
function Medlyn(g0,gs,gs_min)
    Medlyn(promote(g0,gs,gs_min))
end

Medlyn(g0,g1) = Medlyn(g0,g1,oftype(g0,0.001))

Medlyn(;g0,g1) = Medlyn(g0,g1,oftype(g0,0.001))
```

```julia
function inputs(::Medlyn)
    (:Dₗ,:Cₛ,:A)
end
```

```julia
function outputs(::Medlyn)
    (:Gₛ,)
end
```

```julia
Base.eltype(x::Medlyn) = typeof(x).parameters[1]
```
