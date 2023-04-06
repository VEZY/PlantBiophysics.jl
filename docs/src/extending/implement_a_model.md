# [Model implementation in 5 minutes](@id model_implementation_page)

```@setup usepkg
using PlantBiophysics
using PlantSimEngine
using PlantMeteo
```

## Introduction

`PlantBiophysics.jl` was designed to make new model implementation very simple thanks to `PlantSimEngine`. So let's learn about how to implement your own model with a simple example: implementing a new stomatal conductance model.

## Inspiration

If you want to implement a new model, the best way to do it is to start from another implementation.

So for a photosynthesis model, I advise you to look at the implementation of the `FvCB` model in this Julia file: [src/photosynthesis/FvCB.jl](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/photosynthesis/FvCB.jl).

For an energy balance model you can look at the implementation of the `Monteith` model in [src/energy/Monteith.jl](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/energy/Monteith.jl), and for a stomatal conductance model in [src/conductances/stomatal/medlyn.jl](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/conductances/stomatal/medlyn.jl).

## Requirements

In those files, you'll see that in order to implement a new model you'll need to implement:

- a structure, used to hold the parameter values and to dispatch to the right method
- the actual model, developed as a method for the `run!` function
- some helper functions used by the package and/or the users

Let's take a simple example with a new model for the stomatal conductance: the Ball and Berry model.

## Example: the Ball and Berry model

### The structure

The first thing to do is to implement a structure for your model.

The purpose of the structure is two-fold:

- hold the parameter values
- dispatch to the right method when calling the process function

Let's take the [stomatal conductance model from Medlyn et al. (2011)](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/conductances/stomatal/medlyn.jl#L37) as a starting point. The structure of the model (or type) is defined as follows:

```julia
struct Medlyn{T} <: AbstractStomatal_ConductanceModel
    g0::T
    g1::T
    gs_min::T
end
```

The first line defines the name of the model (`Medlyn`), with the types that will be used for the parameters. Then it defines the structure as a subtype of [`AbstractStomatal_ConductanceModel`](@ref). This step is very important as it tells to the package what kind of process the model simulates. In this case, it is a stomatal conductance model, that's why we use [`AbstractStomatal_ConductanceModel`](@ref). We would use [`AbstractPhotosynthesisModel`](@ref) instead for a photosynthesis model, [`AbstractEnergy_BalanceModel`](@ref) for an energy balance model, and [`AbstractLight_InterceptionModel`](@ref) for a light interception model.

These abstract structures are automatically defined when defining a process using the `@process` macro from `PlantSimEngine.jl` (which PlantBiophysics is built upon). 

For another example, the [`Fvcb`](@ref) model is a subtype of [`AbstractPhotosynthesisModel`](@ref). You can check this using:

```@example usepkg
Fvcb <: AbstractPhotosynthesisModel
```

Then comes the parameters names, and their types. The type of the parameters is always forced to be of the same type in our example. This is done using the `T` notation as follows:

- we say that our structure `Medlyn` is a parameterized `struct` by putting `T` in between brackets after the name of the `struct`
- We put `::T` after our parameter names in the `struct`. This way Julia knows that all parameters must be of same type `T`.

The `T` is completely free, you can use any other letter or word instead. If you have parameters that you know will be of different types, you can either force their type, or make them parameterizable too, using another letter, *e.g.*:

```julia
struct YourStruct{T,S} <: AbstractStomatal_ConductanceModel
    g0::T
    g1::T
    gs_min::T
    integer_param::S
end
```

Parameterized types are very useful because they let the user choose the type of the parameters, and potentially dispatch on them.

But why not forcing the type such as the following:

```julia
struct YourStruct <: AbstractStomatal_ConductanceModel
    g0::Float64
    g1::Float64
    gs_min::Float64
    integer_param::Int
end
```

Well, you can do that. But you'll lose a lot of the magic Julia has to offer this way.

For example a user could use the `Particles` type from [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl) to make automatic uncertainty propagation, and this is only possible if the type is parameterizable.

So let's implement a new structure for our stomatal conductance model:

```@example usepkg
struct BandB{T} <: AbstractStomatal_ConductanceModel
    g0::T
    g1::T
    gs_min::T
end
```

Well, the only thing we had to change relative to the one from Medlyn is the name, easy! This is because both models share the same parameters.

### The method

The models are implemented as a new method for the `run!` function. The tailing exclamation point is used in Julia to tell users the function is mutating its input, *i.e.* it modifies it.

Your implementation should always modify the input status and return nothing. This ensures that models compute fast.

We extend `run!` because then `PlantSimEngine` handles every other details, such as checking that the object is correctly initialized, building the dependency graph between models, applying the computations over objects and time-steps in parallel, etc... This is nice because as a developer you don't have to deal with those details, and you can just concentrate on your implementation.

!!! note 
    If your model calls another one (hard-coupled), you'll have to use the internal call directly to avoid the overheads of the generic functions to avoid all checks for performance.

Here we are trying to implement a new stomatal conductance model. Well, this one is the most complicated process to implement actually, because it is computed on two steps: `run!` and `gs_closure`.

`gs_closure` is the function that actually implements the conductance model, but only the stomatal closure part. This one does not modify its input, it computes the result and returns it. Then `run!` uses this output to compute the stomatal conductance. But why not implementing just `run!`? Because `gs_closure` is used elsewhere, usually in the photosynthesis model, before actually computing the stomatal conductance.

In practice, the `run!` implementation is rather generic and will not be modified by developers. They will rather implement their method for `gs_closure`, that will be used automatically by `run!`.

!!! warning
    We need to import all the functions we need to use or extend, so Julia knows we are extending the methods from PlantSimEngine, and not defining our own functions. To do so, you can prefix the functions by the package name, or import them once *e.g.*:
    ```
        import PlantSimEngine: inputs_, outputs_
        import PlantBiohysics: run!, run!
    ```


So let's do it! Here is our own implementation of the stomatal closure for a `ModelList` component models:

```@example usepkg
function PlantBiophysics.gs_closure(::BandB, models, status, meteo, constants, extra)
    models.stomatal_conductance.g1 * meteo.Rh / status.Cₛ
end
```

The first argument (`::BandB`) means this method will only execute when the function is called with a first argument that is of type `BandB`. This is our way of telling Julia that this method is implementing the `BandB` algorithm.

An important thing to note is that our variables are stored in different structures:

- `models`: the models parameters
- `status`: the input and output variables of the models
- `meteo`: the micro-climatic conditions
- `constants`: the constants
- `extras`: any other value or object, this is used for example to pass the node of a MultiScaleTreeGraph

!!! note
    The micro-meteorological conditions are always given for one time-step inside the models methods. The conditions with several time-steps are handled earlier by the generic functions.

OK ! So that's it ? Almost. One last thing to do is to define a method for inputs/outputs so that PlantSimEngine knows which variables are needed for our model, and which it computes. Remember that the actual model is implemented for `run!`, so we have to tell PlantSimEngine which ones are needed, and what are their default value:

- Inputs: `:Rh` and `:Cₛ` for our specific implementation, and `:A` for `run!`
- Outputs: our model does not compute any new variable, and `run!` computes, well, `:Gₛ`

Here is how we actually implement our methods:

```@example usepkg
import PlantSimEngine
function PlantSimEngine.inputs_(::BandB)
    (Rh=-Inf,Cₛ=-Inf,A=-Inf)
end

function PlantSimEngine.outputs_(::BandB)
    (Gₛ=-Inf,)
end
```

Note that both function end with an "_". This is because these functions are internal, they will not be called by the users directly. Users will use `inputs` and `outputs` instead, which call `inputs_` and `outputs_`, but stripping out the default values.

### The utility functions

Before running a simulation, you can do a little bit more for your implementation (optional).

First, you can add a method for type promotion:

```@example usepkg
function BandB(g0,g1,gs_min)
    BandB(promote(g0,g1,gs_min))
end
```

This allows your user to instantiate your model parameters using different types of inputs. For example they may use this:

```julia
BandB(0,2.0,0.001)
```

You don't see a problem? Well your users won't either.

Here's the problem: we use parametric types, and when we declared our structure, we said that all fields in our type will share the same type. This is the `T` here:

```julia
struct BandB{T} <: AbstractStomatal_ConductanceModel
    g0::T
    g1::T
    gs_min::T
end
```

And in our example above, the user provides `0` as the first argument. Well, this is an integer, not a floating point number like the two others. That's were the promotion is really helpful. It will convert all your inputs to the same type. In our example it will convert `0` to `0.0`.

A second thing also is to help your user with default values for some parameters (if applicable). For example a user will almost never change the value of the minimum stomatal conductance. So we can provide a default value like so:

```@example usepkg
BandB(g0,g1) = BandB(g0, g1, oftype(0.001, g0))
```

Now the user can call `BandB` with only two values, and the third one will be set to `0.001`.

Another useful thing to provide to the user is the ability to instantiate your model type with keyword values. You can do it by adding the following method:

```@example usepkg
BandB(;g0,g1) = BandB(g0,g1,oftype(g0,0.001))
```

Did you notice the `;` before the argument? It tells Julia that we want those arguments provided as keywords, so now we can call `BandB` like this:

```@example usepkg
BandB(g0 = 0.0, g1 = 2.0)
```

This is nice, but again, completely optional.

One more thing to implement is a method for the `dep` function that tells PlantSimEngine which processes (and models) are needed for your model to run (*i.e.* if your model is coupled to another model).

Our example model does not call another model, so we don't need to implement it. But we can look at *e.g.* the implementation for [`Fvcb`](@ref) to see how it works:

```julia
PlantSimEngine.dep(::Fvcb) = (stomatal_conductance=AbstractStomatal_ConductanceModel,)
```

Here we say to PlantSimEngine that the `Fvcb` model needs a model of type `AbstractStomatal_ConductanceModel` in the stomatal conductance process.

The last optional thing to implement is a method for the `eltype` function:

```@example usepkg
Base.eltype(x::BandB{T}) where {T} = T
```

This one helps Julia to know the type of the elements in your structure, and make it faster.

OK that's it! Now you have a full new implementation of the stomatal conductance model! I hope it was clear and you understood everything. If you think some sections could be improved, you can make a PR on this doc, or open an issue so I can improve it.

## More details on model implementations

Here is another example with a different approach in case you need it. So let's change our example from the stomatal conductance to the photosynthesis.
For example [`Fvcb`](@ref) implements the model or Farquhar et al. (1980) to simulate the photosynthesis of C3 plants.

When the user calls `run!`, PlantBiophysics looks into the component models type, and the type of the model implemented for the photosynthesis, in this case, [`Fvcb`](@ref).

Then, it calls another, internal method of [`run!`](@ref) that will dispatch the computation to the method that implements the model. This method looks like this:

```julia
function PlantSimEngine.run!(::Fvcb, models, status, meteo, constants=Constants(), extras=nothing)

    [...]

end
```

Where `[...]` represent the lines of code implementing the model (not shown here).

The interesting bit is in the function declaration at the top. This is where all the magic happens. The first argument let Julia know that this is the method for computing the `Fvcb` model.

Now if we look again at what are the fields of a `ModelList`:

```@example usepkg
fieldnames(ModelList)
```

we see that it has two fields: `models` and `status`. The first one is a list of models named after the process they simulate. So if we want to simulate the photosynthesis with the `Fvcb` model, our `ModelList` needs an instance of the [`Fvcb`](@ref) structure for the `photosynthesis` process, like so:

```@example usepkg
leaf = ModelList(Fvcb());
leaf.models.photosynthesis
```

The `photosynthesis` field is then used as the first argument to the call to the internal method of `run!`, which will call the method that implements [`Fvcb`](@ref), because our `photosynthesis` field is of type [`Fvcb`](@ref).

So if we want to implement our own model for the photosynthesis, we could do:

```@example usepkg
# Make the struct to hold the parameters:
struct OurModel{T} <: AbstractPhotosynthesisModel
    a::T
    b::T
    c::T
end

# Instantiate the struct with default values + kwargs:
function OurModel(;a = 400.0, b = 1000.0, c = 1.5)
    OurModel(promote(a,b)...)
end

# Define inputs:
function PlantSimEngine.inputs_(::OurModel)
    (aPPFD=-Inf, Tₗ=-Inf, Cₛ=-Inf)
end

# Define outputs:
function PlantSimEngine.outputs_(::OurModel)
    (A=-Inf, Gₛ=-Inf)
end

# Tells Julia what is the type of elements:
Base.eltype(x::OurModel{T}) where {T} = T

# Implement the photosynthesis model:
function PlantSimEngine.run!(::OurModel, models, status, meteo, constants=Constants(), extras=nothing)

    status.A =
        status.Cₛ / models.photosynthesis.a +
        status.aPPFD / models.photosynthesis.b +
        status.Tₗ / models.photosynthesis.c

    PlantSimEngine.run!(models.stomatal_conductance, models, status, meteo, constants, extras)
end
```

🥳 And that's it! 🥳

We have a new model for photosynthesis that is coupled with the stomatal conductance.

!!! warning
    This is a dummy photosynthesis model. Don't use it, it is very wrong biologically speaking!

!!! note
    Notice that we compute the stomatal conductance directly using the internal method of `run!` that takes the type of model as first argument. We do this for speed, because the generic function `run!` does some checks on its inputs every time it is called, while the internal method only does the computation. We don't need the extra checks and dependency graph computations because they are already done at the first call.

Now if we want to make a simulation, we can simply do:

```@example usepkg
using PlantMeteo
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf =
    ModelList(
        OurModel(1.0, 2.0, 3.0),
        Medlyn(0.03, 12.0),
        status = (Tₗ = 25.0, aPPFD = 1000.0, Cₛ = 400.0, Dₗ = meteo.VPD)
    )
# NB: we need  to initalise Tₗ, aPPFD and Cₛ

run!(leaf,meteo,Constants())
leaf[:A]
```
