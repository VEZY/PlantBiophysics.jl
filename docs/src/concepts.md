# Concepts and design

A particularity of this package is its capability to compose with other code. Users can add their own computations for processes easily, and still benefit freely from all the other ones. This is made possible thanks to Julia's multiple dispatch. You'll find more information in this section.

## Objects

Scene, object, component, list of models, mtg.

## Processes

At the moment, this package is designed to simulate four different processes.

- photosynthesis
- stomatal conductance
- energy balance
- light interception (no models at the moment, but coming soon!)

These processes can be simulated using different models. Each process is defined by a generic function, and an abstract struct.

For example [`AbstractAModel`](@ref) is the abstract structure used as a supertype of all photosynthesis models, and the [`photosynthesis`](@ref) function is used to simulate the process.

Then, particular implementations of models are used to simulate the processes. These implementations are made using a concrete type (or struct) to hold the parameters of the model and their values, and a method for a function.

For example the Farquhar–von Caemmerer–Berry (FvCB) model (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981) is implemented to simulate the photosynthesis using:

- the [`Fvcb`](@ref) struct to hold the values of all parameters for the model (use `fieldnames(Fvcb)` to get them)
- its own method for the [`assimilation!`](@ref) function.

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

## Models

The models used to simulate the processes are implemented using a concrete type (or struct) to hold the parameter values of the models, and methods for a several functions.

For example the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981) is implemented using the [`Fvcb`](@ref) struct. The struct holds the values of all parameters for the model (use `fieldnames(Fvcb)` to get them).
