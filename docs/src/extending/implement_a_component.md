# Implement a new component models

```@setup usepkg
using PlantBiophysics, MutableNamedTuples

struct WoodModels{
    I<:Union{Missing,AbstractInterceptionModel},
    E<:Union{Missing,AbstractEnergyModel},
    S<:MutableNamedTuple
} <: AbstractComponentModel

    interception::I
    energy_balance::E
    status::S
end

wood = WoodModels(
    missing,
    Monteith(),
    MutableNamedTuple(Rₛ = 13.0, sky_fraction = 1.0, d = 0.03)
)

function WoodModels(; interception = missing, energy_balance = missing, status...)
    status = init_variables_manual(interception, energy_balance; status...)
    WoodModels(interception, energy_balance, status)
end
```

## Introduction

`PlantBiophysics.jl` was designed to make the implementation of new component models easy and fast. Let's learn about how to implement your own component models with a simple example: implementing a component models structure for wood.

!!! warning
    Implementing a new component model should be very rare. Make sure you really need it before creating it. If you have a photosynthetic organ, look into [`ModelList`](@ref), if you have a non-photosynthetic component, look into [`ComponentModels`](@ref). Eventually, ou can also propose a pull request to add a new process to them if really needed so everybody can use the models and the new process. If you feel you need a brand new component and that you want to implement models for each of their processes, you're in the right place.

## Inspiration

As for implementing a new model, the most straightforward way is to look at the code of ones already implemented.

Let's look at [the code of the `ComponentModels`](https://github.com/VEZY/PlantBiophysics.jl/tree/master/src/component_models/componentmodels.jl) for example.

In this file we find:

- The definition of the structure
- A helper method for its instanciation using keyword arguments and `missing` as a default value for the models.
- A method to copy the structure, and copy with a new `status`

## The structure

The first thing to do is to import the packages that we need:

```julia
using PlantBiophysics, MutableNamedTuples
```

!!! note
    `MutableNamedTuples` is needed to make our own component models.

Now we can implement the structure that defines the component models. Remember that its purpose is two-fold: declare the models used for each process, and keep track of the variables values.

Let's call our example wood component models `WoodModels`. Here is how we would define its structure:

```julia
struct WoodModels{
    I<:Union{Missing,AbstractInterceptionModel},
    E<:Union{Missing,AbstractEnergyModel},
    S<:MutableNamedTuple
} <: AbstractComponentModel

    interception::I
    energy_balance::E
    status::S
end
```

OK, that's a lot of information in few lines. Let's break it up.

`struct` in Julia is used to define our own types. It is written like so:

```julia
struct StructName
    field1
    field2
end
```

Then we can instantiate an object with our new type by calling it like a function with positional parameter values that will be used to give values for its fields. The fields here are `field1` and `field2`.

So to instantiate our structure, we would do *e.g.*:

```julia
StructName(1,2)
```

Following this logic, the fields for our `WoodModels` are `interception`, `energy_balance` and `status`. Right. Now sometimes we want the fields of a structure to be of a certain type. To tell Julia that fields must be of a given type, we can provide the type after the field name like so:

```julia
struct StructName2
    field1::Float64
    field2::Int
end
```

Now the user must provide a value of type `Float64` for `field1`, and `Int` for `field2`:

```julia
StructName2(1,2) # doesn't work
StructName2(1.0,2) # does work
```

But what if I want the user to be able to give whatever type he wants as input, but I want to be able to tell apart a structure with one type and another with another type? Well this time you'll use parametric types. Parametric types helps us fix the type of the fields on the type signature, *e.g.*:

```julia
struct StructName3{T<:Number, S<:Number}
    field1::T
    field2::S
end
```

Here both fields should be numbers, but when instantiate a struct the type of the fields is notified:

```julia
julia> StructName3(1.0,1)
StructName3{Float64, Int64}(1.0, 1)
```

Note the `{Float64, Int64}` part that tells us what is the type of each field.

This is exactly what we are using for our own component models structures:

```julia
struct WoodModels{
    I<:Union{Missing,AbstractInterceptionModel},
    E<:Union{Missing,AbstractEnergyModel},
    S<:MutableNamedTuple
} <: AbstractComponentModel

    interception::I
    energy_balance::E
    status::S
end
```

And what it tells us is that the interception model must be either a `Missing` value or an [`AbstractInterceptionModel`](@ref), the energy model must be `Missing` or an [`AbstractEnergyModel`](@ref), and the `status` must be a `MutableNamedTuple`.

Another important thing to note here is that our component models structure defines two processes: `interception` and `energy_balance`. So only these two processes can be simulated for this type of components models.

Now a last information, the `<: AbstractComponentModel` part tells Julia that our structure is a component models and should be treated like such. This gives your component models access to some generic methods graciously provided by PlantBiophysics, such as [`status`](@ref).

So by default you can index your structure with a variable name, and if it is instantiated, it will return it:

```@example usepkg
wood = WoodModels(
    missing,
    Monteith(),
    MutableNamedTuple(Rₛ = 13.0, sky_fraction = 1.0, d = 0.03)
)

status(wood)
```

And we can get the value of a given variable too:

```@example usepkg
status(wood, :Rₛ)
```

## The methods

Some methods are not generic enough, and should be defined by users when they implement a new component models.

### Instantiation with kwargs

The first method to implement is crucial for users, it helps them define the structure by providing the values as keyword arguments (kwargs) with default values:

```julia
function WoodModels(; interception = missing, energy_balance = missing, status...)
    status = init_variables_manual(interception, energy_balance; status...)
    WoodModels(interception, energy_balance, status)
end
```

What happens here? Well it is rather simple. We define a new method to call `WoodModels` with keyword arguments, meaning the user can give the name of the argument to provide a value. We also define `missing` as the default value for all processes, because we consider that the process is not simulated by default if no value is provided.

Finally, we allow the users to provide the status variables as keyword arguments instead of a MutableNamedTuple. This is really important because now they don't need to explicitly import the `MutableNamedTuples` package to instantiate your structure.

For example one can instantiate the structure like so now:

```@example usepkg
WoodModels(energy_balance = Monteith(), Rₛ = 13.0, sky_fraction = 1.0, d = 0.03)
```

Our newly created structure has a model to simulate the energy balance, but no model to compute the light interception. It is completely initialized, with values for `Rₛ`, `sky_fraction` and `d`.

I think we can agree this form is way cleaner than the previous one we saw earlier:

```julia
WoodModels(
    missing,
    Monteith(),
    MutableNamedTuple(Rₛ = 13.0, sky_fraction = 1.0, d = 0.03)
)
```

### Copy of the structure

We also need to implement a method to tell Julia how we can copy our structure. This is very easy, we just extend the `copy` function from `Base` like so:

```@example usepkg
function Base.copy(l::T) where {T<:WoodModels}
    WoodModels(
        l.interception,
        l.energy_balance,
        deepcopy(l.status)
    )
end
```

!!! warning
    It is very important to write `Base.copy`, not just `copy` because it tells Julia that we are adding a method to the already known function from Base.

What happens here? Well we tell Julia that when a user use the `copy` function on an object of type (or subtype) `WoodModels`, it has to use the method we just defined. And the method simply create a new `WoodModels` with the same values than the one we just passed, but with a status that is a deep copy of its status. Why a deep copy? Because else we would end-up with a status that points to the same address on your computer memory, and modifying one object would modify the other. That's not what we call a copy.

And finally, the last step to create your very own component models structure is to implement a `copy` method but with two arguments: the component models structure you want to copy like before, and the new status. This method helps users create new component models structures based on another one, but with different values from the start. Again, very simple, here's the code:

```@example usepkg
function Base.copy(l::T, status) where {T<:WoodModels}
    WoodModels(
        l.interception,
        l.energy_balance,
        status
    )
end
```

The only difference with the previous method is that we provide the new status as an argument, not as a deep copy of the original `WoodModels`.

And that's it! You did it, there's know a new component models structure available to you.

What's the next step now? Well, implementing models for it! You can learn more about it on [`this page`](@ref model_implementation_page).

## Implement a new process

If your new component models implement a new process, you'll need to define the generic methods associated to it that helps run its simulation for:

- one or several time-steps
- one or several components
- an MTG from MultiScaleTreeGraph

...and all the above with a mutating function and a non-mutating one.

This is a lot of work! But fortunately PlantBiophysics provides a macro to generate all of the above: [`gen_process_methods`](@ref).

This macro takes only one argument: the name of the non-mutating function.

So for example all the photosynthesis methods are created using just this tiny line of code:

```julia
@gen_process_methods photosynthesis
```

!!! note
    The function is not exported by the package as it is very rarely used. To use it you'll have to prefix it by the name of the package.

So imagine we have a solar panel in our scene, and we want to simulate its production, we could create a new components model called `PhotoVoltaicModels` with a light interception process, an energy balance process, and a new process called `production`. To create the generic functions to simulate the production we would do:

```julia
PlantBiophysics.@gen_process_methods production
```

And that's it! You created a new process called production, with the following functions:

- `production!`: the mutating function
- `production`: the non-mutating function
- `production!_`: the function that actually make the computation. You'll have to implement methods for each model you need, else it will not work.
