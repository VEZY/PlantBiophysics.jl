# Components models

## Components

A component is the most basic structural unit of an object. Its nature depends on the object itself, and the scale of the description. We can take a plant as an object for example. Reproductive organs aside, we can describe a plant with three different types of organs:

- the leaves
- the internodes
- the roots

Those three organs we present here are what we call components.

!!! note
    Of course we could describe the plant at a coarser (*e.g.* axis) or finer (*e.g.* growth units) scale, but this is not relevant here.

PlantBiophysics doesn't implement components *per se*, because it is more the job of other packages. However, PlantBiophysics provides components models.

!!! tip
    [MultiScaleTreeGraph](https://vezy.github.io/MultiScaleTreeGraph.jl/stable/) implements a way of describing a plant as a tree data-structure. PlantBiophysics even provides methods for computing processes over such data.

## Component models

Components models are structures that define which models are used to simulate the biophysical processes of a component.

All component models are subtypes of the [`AbstractComponentModel`](@ref) abstract type. At the time, PlantBiophysics provides two component models: [`ModelList`](@ref) or photosynthetic components (*e.g.* leaves) and the more generic [`ComponentModels`](@ref) for any other components (*e.g.* wood, soil...).

The component models lists the processes that can be simulated for a given component, and is used to associate a given model and its parameter values to each process for their simulation. It also has an obligatory `status` field that helps keeping track of the input ans outputs values for the models.

!!! tip
    These are provided as defaults, but you can easily define your own component models if you want, and then implement the models for each of its processes.
