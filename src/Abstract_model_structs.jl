"""
Abstract model type. All models are subtypes of this one, see *e.g.* [`AbstractAModel`](@ref)
"""
abstract type AbstractModel end

"""
Abstract structure that defines component models, which are structures that lists the processes
that can be simulated for a given component. For example [`ModelList`](@ref) is a concrete
implementation of an `AbstractComponentModel`.

All `AbstractComponentModel` must have a `model` and a `status` fields. It used by
PlantBiophysics to manage the inputs/outputs of the models and keep track of their values.
"""
abstract type AbstractComponentModel <: AbstractModel end
