# Concepts and design

```@setup usepkg
using PlantBiophysics
```

A particularity of this package is its ability to compose with other code. Users can add their own computations for processes easily, and still benefit freely from all the other ones. This is made possible thanks to Julia's multiple dispatch. You'll find more information in this section.

## Objects

**Fill this section**

Scene, object, component, list of models, mtg.

## Processes

At the moment, this package is designed to simulate four different processes:

- photosynthesis
- stomatal conductance
- energy balance
- light interception (no models at the moment, but coming soon!)

These processes can be simulated using different models. Each process is defined by a generic function, and an abstract structure.

For example [`AbstractAModel`](@ref) is the abstract structure used as a supertype of all photosynthesis models, and the [`photosynthesis`](@ref) function is used to simulate this process.

Then, particular implementations of models are used to simulate the processes. These implementations are made using a concrete type (or `struct`) to hold the parameters of the model and their values, and a method for a function.

For example the Farquhar–von Caemmerer–Berry (FvCB) model (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981) is implemented to simulate the photosynthesis using:

- the [`Fvcb`](@ref) struct to hold the values of all parameters for the model (use `fieldnames(Fvcb)` to get them)
- its own method for the [`assimilation!`](@ref) function, which is used when a component has the [`Fvcb`](@ref) type in its photosynthesis field.

Then, the user calls the [`photosynthesis`](@ref) function, which call the [`assimilation!`](@ref) function itself under the hood. And the right model is found by searching which method of [`assimilation!`](@ref) correspond to the [`Fvcb`](@ref) struct (using Julia's multiple dispatch).

## Abstract types

The higher abstract type is [`AbstractModel`](@ref). All models in this package are subtypes of this structure.

The second one is [`AbstractComponentModel`](@ref), which is a subtype of [`AbstractModel`](@ref). It is used to describe a set of models for a given component.

Then comes the abstract models for each process represented:

- [`AbstractAModel`](@ref): assimilation (photosynthesis) abstract struct
- [`AbstractGsModel`](@ref): stomatal conductance abstract struct
- [`AbstractInterceptionModel`](@ref): light interception abstract struct
- [`AbstractEnergyModel`](@ref): energy balance abstract struct

All models for a given process are a subtype of these abstract struct. If you want to implement your own model for a process, you must make it a subtype of them too.

For example, the [`Fvcb`](@ref) model is a subtype of [`AbstractAModel`](@ref). You can check this using:

```@example usepkg
Fvcb <: AbstractAModel
```

## Concrete types: Models

### Model types

The models used to simulate the processes are implemented using a concrete type (or `struct`) to hold the parameter values of the models, and to dispatch to the right method for the process functions.

For example, the Farquhar–von Caemmerer–Berry model for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981) is implemented using the [`Fvcb`](@ref) struct. The struct holds the values of all parameters for the model.

We can use `fieldnames` to get all the parameter names of this model:

```@example usepkg
fieldnames(Fvcb)
```

That's a lot of parameters! But no worries, you don't need to provide them all (see [Photosynthesis](@ref photosynthesis_page) for further details).

### Model implementation

Then we have an implementation of the model (*i.e.* the actual algorithm) for the given process it is meant to simulate. In this case, [`Fvcb`](@ref) is made to simulate the [`photosynthesis`](@ref), and this process uses a function called [`assimilation!`](@ref), which implements the models for the photosynthesis ([`photosynthesis`](@ref) is just a nice wrapper for the users).

So the actual implementation of the Fvcb model is written like this:

```julia
function assimilation!(leaf::LeafModels{I,E,<:Fvcb,<:AbstractGsModel,S}, meteo, constants = Constants()) where {I,E,S}

    [...]

end
```

Where `[...]` represent the lines of code implementing the model.

The interesting bit is in the function declaration at the top, this is how all the magic happens. The first argument is called `leaf`, and is an instance of a [`LeafModels`](@ref). Now if we look at what are the fields of a [`LeafModels`](@ref):

```@example usepkg
fieldnames(LeafModels)
```

we find that it is a structure that holds all models used to simulate the processes of a leaf. So if we want to simulate the photosynthesis with the `Fvcb` model, our leaf would have an instance of the [`Fvcb`](@ref) structure in its `photosynthesis` field, like so:

```@example usepkg
leaf = LeafModels(photosynthesis = Fvcb());
leaf.photosynthesis
```

The `photosynthesis` field is the third one in a [`LeafModels`](@ref). So what our function definition says with this:

```julia
leaf::LeafModels{I,E,<:Fvcb,<:AbstractGsModel,S}
```

is simply that the leaf argument must be a [`LeafModels`](@ref) with its third field being of type [`Fvcb`](@ref). This seems perfectly right because what we are talking about here is a function that implements the [`Fvcb`](@ref) model. Note also that the fourth field must be a subtype of [`AbstractGsModel`](@ref), hence a stomatal conductance model (whatever the model). This is because the `Fvcb` model couples the assimilation with the stomatal conductance, so we need to simulate the stomatal conductance too for the computation of the assimilation (this is made inside the function).

Then we also have `I`, `E`, and `S` that are defined as `where {I,E,S}`. This means we expect something here, but we don't put any constraint on what it is. This is because we don't need explicitly a model for these processes (I: light interception, E: energy balance, S: status) to simulate the photosynthesis as soon as we have the values of some required input variables.

### Inputs and outputs

The status field of the [`LeafModels`](@ref) is used to keep track of the status of the variables related to the leaf. It is used with two purposes:

- input: provide values for variables as input of the model
- output: give the simulated values for output variables

It is possible to know which variables are required as model input using [`inputs`](@ref), e.g. for [`Fvcb`](@ref):

```@example usepkg
inputs(Fvcb())
```

and the outputs using [`outputs`](@ref)

```@example usepkg
outputs(Fvcb())
```

It is also possible to get which variables we need to instantiate before calling a process function using [`to_initialise`](@ref) on one or several models, or directly on a leaf:

```@example usepkg
leaf = LeafModels(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03,12.0));
to_initialise(leaf)
```

If some models simulate the input variables for other models, [`to_initialise`](@ref) will return the variables that e can't simulate only. For example we don't need to initialize the leaf temperature for the photosynthesis if we provide an energy balance model that will simulate it:

```@example usepkg
leaf = LeafModels(energy = Monteith(), photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03,12.0));
to_initialise(leaf)
```

Now the inputs have changed, because some are simulated and others are required by the `Monteith()` model.
