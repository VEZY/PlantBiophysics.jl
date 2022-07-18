# [Model implementation in 5 minutes](@id model_implementation_page)

```@setup usepkg
using PlantBiophysics
```

## Introduction

`PlantBiophysics.jl` was designed to make new model implementation very simple. So let's learn about how to implement your own model with a simple example: implementing a new stomatal conductance model.

## Inspiration

If you want to implement a new model, the best way to do it is to start from another implementation.

So for a photosynthesis model, I advise you to look at the implementation of the FvCB model in this Julia file: [src/photosynthesis/FvCB.jl](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/photosynthesis/FvCB.jl).

For an energy balance model you can look at the implementation of the Monteith model in [src/energy/Monteith.jl](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/energy/Monteith.jl), and for a stomatal conductance model in [src/conductances/stomatal/medlyn.jl](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/conductances/stomatal/medlyn.jl).

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

Let's take the [stomatal conductance model from Medlyn et al. (2011)](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/conductances/stomatal/medlyn.jl#L37) as a starting point. The structure of the model (or type) is defined as follows:

```julia
struct Medlyn{T} <: AbstractGsModel
    g0::T
    g1::T
    gs_min::T
end
```

The first line defines the name of the model (`Medlyn`), with the types that will be used for the parameters. Then it defines the structure as a subtype of [`AbstractGsModel`](@ref). This step is very important as it tells to the package what kind of model it is. In this case, it is a stomatal conductance model, that's why we use [`AbstractGsModel`](@ref). We would use [`AbstractAModel`](@ref) instead for a photosynthesis model, [`AbstractEnergyModel`](@ref) for an energy balance model, and [`AbstractInterceptionModel`](@ref) for a light interception model.

For another example, the [`Fvcb`](@ref) model is a subtype of [`AbstractAModel`](@ref). You can check this using:

```@example usepkg
Fvcb <: AbstractAModel
```

Then comes the parameters names, and their types. The type of the parameters is always forced to be of the same type in our example. This is done using the `T` notation as follows:

- we say that our structure `Medlyn` is a parameterized struct by putting `T` in between brackets after the name of the struct
- We put `::T` after our parameter names in the struct. This way Julia knows that all parameters must be of type `T`.

The `T` is completely free, you can use any other letter or word instead. If you have parameters that you know will be of different types, you can either force their type, or make them parameterizable too using another letter, *e.g.*:

```julia
struct YourStruct{T,S} <: AbstractGsModel
    g0::T
    g1::T
    gs_min::T
    integer_param::S
end
```

Parameterized types are very useful because they let the user choose the type of the parameters, and make the computations fast.

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
struct BandB{T} <: AbstractGsModel
    g0::T
    g1::T
    gs_min::T
end
```

Well, the only thing we had to change relative to the one from Medlyn is the name, easy! This is because both models share the same parameters.

### The method

The models are implemented in a function named after the process and a "!\_" as a suffix. The exclamation point is used in Julia to tell users the function is mutating, *i.e.* it modifies its input.

Your implementation should always modify the input object (here the `leaf`) and return nothing. This ensures that models compute fast. The "_" suffix is used to tell users that this is the internal implementation.

Remember that PlantBiophysics only exports the generic functions of the processes to users because they are the one that handles every other details, such as checking that the object is correctly initialized, and applying the computations over objects and time-steps. This is nice because as a developer you don't have to deal with those details, and you can just concentrate on your implementation.

However, you have to remember that if your model calls another one, you'll have to use the internal implementation directly to avoid the overheads of the generic functions (you don't want all these checks).

So if you want to implement a new photosynthesis model, you have to make your own method for the `photosynthesis!_` function. But here we are trying to implement a new stomatal conductance model. Well, this one is the most complicated process to implement actually, because it is computed on two steps: `stomatal_conductance!_` and `gs_closure`.

`gs_closure` is the function that actually implements the conductance model, but only the stomatal closure part. This one does not modify its input, it computes the result and returns it. Then `stomatal_conductance!_` uses this output to compute the stomatal conductance. But why not implementing just `stomatal_conductance!_`? Because `gs_closure` is used elsewhere, usually in the photosynthesis model, before actually computing the stomatal conductance.

So in practice, the `stomatal_conductance!_` implementation is rather generic and will not be modified by developers. They will rather implement their method for `gs_closure`, that will be used automatically by `stomatal_conductance!_`.

So let's do it! Here is our own implementation of the stomatal closure for a `LeafModels` component models:

```julia
function gs_closure(leaf::LeafModels{I,E,A,<:BandB,S},meteo) where {I,E,A,S}
    leaf.stomatal_conductance.g1 * meteo.Rh / leaf.status.Cₛ
end
```

There is an important bit of code to understand here: `leaf::LeafModels{I,E,A,<:BandB,S}`. The right-hand side of the `::` means that the `leaf` argument must be of `LeafModels` type, with any parameterized models for all processes, except for the stomatal conductance that must be of `BandB` type (or subtype).

This is important because it restricts the use of your model to one component only. But this is the right solution because component models such as `LeafModels` should implement their own models. And if a model is generic to all types of component models, not just `LeafModels`, then you must define it for each (or define a function that is called by each).

A second important thing to note is that our variables are stored in different structures:

- the parameters come from the model (`leaf.stomatal_conductance` here)
- the micro-climatic conditions comes from the `meteo` structure
- the variables are stored in the component models `status` (`leaf.status` here)

!!! note
    The micro-meteorological conditions are always given for one time-step inside the models methods, so they are always of `Atmosphere` type. The `Weather` type of conditions are handled earlier by the generic functions.

OK ! So that's it ? Almost. One last thing to do is to define a method for inputs/outputs so that PlantBiophysics knows which variables are needed for our model, and which it computes. Remember that the actual model is implemented for `stomatal_conductance!_`, so we have to tell PlantBiophysics which ones are needed overall:

- Inputs: `:Rh` and `:Cₛ` for our specific implementation, and `:A` for `stomatal_conductance!_`
- Outputs: our model does not compute any new variable, and `stomatal_conductance!_` computes, well, `:Gₛ`

And here is how we actually implement our methods:

```julia
function inputs(::BandB)
    (:Rh,:Cₛ,:A)
end

function outputs(::BandB)
    (:Gₛ,)
end
```

OK so this time that's it right? Yes! You made your own implementation of a stomatal conductance model!

### The utility functions

OK you got me I lied. But just a little bit. Yes you can do more for your implementation, but it is only optional.

First, you can add a method for type promotion:

```julia
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
struct BandB{T} <: AbstractGsModel
    g0::T
    g1::T
    gs_min::T
end
```

And in our example above, the user provides `0` as the first argument. Well, this is an integer, not a float like the two others. That's were the promotion is really helpful. It will convert all your inputs to the same type. In our example it will convert `0` to `0.0`. Nice to have this one right?

A second thing also is to help your user with default values for some parameters (if applicable). For example a user will almost never change the value of the minimum stomatal conductance. So we can provide a default value like so:

```julia
BandB(g0,g1) = BandB(g0, g1, 0.001)
```

Now the user can call `BandB` with only two values, and the third one will be set to `0.001`.

Another useful thing to provide to the user is the ability to instantiate your model type with keyword values. You can do it by adding the following method:

```julia
BandB(;g0,g1) = BandB(g0,g1,oftype(g0,0.001))
```

Did you notice the `;` before the argument? It tells Julia that we want those arguments provided as keywords, so now we can call `BandB` like this:

```julia
BandB(g0 = 0.0, g1 = 2.0)
```

This is nice, but again, completely optional.

The last optional thing to implement is a method for the `eltype` function:

```julia
Base.eltype(x::BandB) = typeof(x).parameters[1]
```

This one helps Julia to know the type of the elements in your structure, and make it faster.

OK that's it! Now you have a full new implementation of the stomatal conductance model! I hope it was clear and you understood everything. If you think some sections could be improved, you can make a PR on this doc, or open an issue so I can improve it.

## More details on model implementations

Here is another example with a different approach in case you need it. So let's change our example from the stomatal conductance to the photosynthesis.
For example [`Fvcb`](@ref) implements the model or Farquhar et al. (1980) to simulate the [`photosynthesis`](@ref) of C3 plants.

When the user calls the `photosynthesis` function, or its mutating version `photosynthesis!`, PlantBiophysics looks into the component models type, and the type of the model implemented for the photosynthesis, in this case, [`Fvcb`](@ref).

Then, it calls the internal function [`photosynthesis!_`](@ref) that will dispatch the computation to the method implementing it for the given type of component models and model. This method looks like this:

```julia
function photosynthesis!_(leaf::LeafModels{I,E,<:Fvcb,<:AbstractGsModel,S}, meteo, constants = Constants()) where {I,E,S}

    [...]

end
```

Where `[...]` represent the lines of code implementing the model (not shown here).

The interesting bit is in the function declaration at the top. This is where all the magic happens. The first argument is called `leaf`, and is an instance of a [`LeafModels`](@ref) with a photosynthesis type that is a (sub-)type of `Fvcb`: `LeafModels{I,E,<:Fvcb,<:AbstractGsModel,S}`. We also note that this particular implementation needs a model for the stomatal conductance (this is the `<:AbstractGsModel` bit).

Now if we look again at what are the fields of a [`LeafModels`](@ref):

```@example usepkg
fieldnames(LeafModels)
```

we see that it holds all models used to simulate the processes of a leaf. So if we want to simulate the photosynthesis with the `Fvcb` model, our leaf would have an instance of the [`Fvcb`](@ref) structure in its `photosynthesis` field, like so:

```@example usepkg
leaf = LeafModels(photosynthesis = Fvcb());
leaf.photosynthesis
```

The `photosynthesis` field is the third one in a [`LeafModels`](@ref). So what our function definition says with this:

```julia
leaf::LeafModels{I,E,<:Fvcb,<:AbstractGsModel,S}
```

...is simply that the leaf argument must be a [`LeafModels`](@ref) with its third field being of type [`Fvcb`](@ref). This seems perfectly right because what we are talking about here is a function that implements the [`Fvcb`](@ref) model for a `LeafModels`. Note again that the fourth field must be a subtype of [`AbstractGsModel`](@ref), hence a stomatal conductance model must be provided (whatever the model). This is because the `Fvcb` model couples the assimilation with the stomatal conductance, so we need to simulate the stomatal conductance too for the computation of the assimilation (this is made inside the function).

Then we also have `I`, `E`, and `S` that are defined as `where {I,E,S}`. This means we expect something here, but we don't put any constraint on what it is. This is because we don't need explicitly a model for these processes (I: light interception, E: energy balance, S: status) to simulate the photosynthesis as soon as we have the values of some required input variables.

So if we want to implement our own model for the photosynthesis, we could do:

```julia
# Make the struct to hold the parameters:
struct OurModel{T} <: AbstractAModel
    a::T
    b::T
    c::T
end

# Instantiate the struct with default values + kwargs:
function OurModel(;a = 400.0, b = 1000.0, c = 1.5)
    OurModel(promote(a,b)...)
end

# Define inputs:
function inputs(::OurModel)
    (:PPFD, :Tₗ, :Cₛ)
end

# Define outputs:
function outputs(::OurModel)
    (:A, :Gₛ, :Cᵢ)
end

# Tells Julia what is the type of elements:
Base.eltype(x::OurModel) = typeof(x).parameters[1]

# Implement the photosynthesis model:
function photosynthesis!_(leaf::LeafModels{I,E,<:OurModel,<:AbstractGsModel,S}, meteo, constants = Constants()) where {I,E,S}

    leaf.status.A =
        leaf.status.Cₛ / leaf.photosynthesis.a +
        leaf.status.PPFD / leaf.photosynthesis.b +
        leaf.status.Tₗ / leaf.photosynthesis.c

    stomatal_conductance!_(leaf, st_closure)
end
```

🥳 And that's it! 🥳

We have a new model for photosynthesis that is coupled with the stomatal conductance.

!!! warning
    This is a dummy photosynthesis model. Don't use it, it is very wrong biologically speaking!

!!! note
    Notice that we compute the stomatal conductance directly using the internal function `stomatal_conductance!_`. We do this for speed, because the generic function `stomatal_conductance!` does some checks on its inputs every time it is called, while `stomatal_conductance!_` only does the computation. We don't need the extra checks because they are already made when calling `photosynthesis!`.

Lastly, we note that the implementations of the models are linked to a given component models structure, here `LeafModels`. Some models -like a light interception model- are generic enough to be used for any components though. In this case we recommend to put the algorithm into a function that will be called by the generic function for each component.

For exemple we could define the following dummy interception structure:

```julia
struct DummyInterception{T} <: AbstractEnergyModel
    PAR::T
    w_to_umol::T
    sky_fraction::T
end

DummyInterception(;PAR = 0.48, w_to_umol = 4.57, sky_fraction = 1.0) = DummyInterception(PAR, w_to_umol,sky_fraction)

function inputs(::DummyInterception)
    (:area,)
end

function outputs(::DummyInterception)
    (:Rₛ, :PPFD, :sky_fraction)
end

Base.eltype(x::DummyInterception) = typeof(x).parameters[1]
```

Now let's say its computation is always the same, whatever the component models structure:

```julia
function dummy_interception(object, meteo)
    object.status.sky_fraction = object.interception.sky_fraction
    object.status.Rₛ = object.status.area * meteo.Ri_SW_f
object.status.PPFD = object.status.Rₛ * object.interception.PAR * object.interception.w_to_umol
end
```

So what's the procedure to implement it for all component models? Well, we call this function from all implementations, *e.g.*:

```julia
function light_interception!_(leaf::LeafModels{<:DummyInterception,E,A,Gs,S}, meteo::AbstractAtmosphere, constants = Constants()) where {E,A,Gs,S}
    dummy_interception(leaf, meteo)
end

function light_interception!_(leaf::ComponentModels{<:DummyInterception,E,A,Gs,S}, meteo::AbstractAtmosphere, constants = Constants()) where {E,A,Gs,S}
    dummy_interception(leaf, meteo)
end
```
