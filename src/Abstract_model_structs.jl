"""
Abstract model type. All models are subtypes of this one, see *e.g.* [`AbstractAModel`](@ref)
"""
abstract type AbstractModel end

"""
Abstract structure that defines component models, which are structures that lists the processes
that can be simulated for a given component. For example [`LeafModels`](@ref) is a concrete
implementation of an `AbstractComponentModel` for photosynthetic components (*e.g.* leaves).

All `AbstractComponentModel` must have a `status` field. It used by PlantBiophysics to manage
the inputs/outputs of the models and keep track of their values.
"""
abstract type AbstractComponentModel <: AbstractModel end


"""
Assimilation (photosynthesis) abstract model. All photosynthesis models must be a subtype of
this.
"""
abstract type AbstractAModel <: AbstractModel end

"""
Stomatal conductance abstract model. All stomatal conductance models must be a subtype of
this.

An AbstractGsModel subtype struct must implement at least a g0 field.
"""
abstract type AbstractGsModel <: AbstractModel end

"""
Light interception abstract struct. All light interception models must be a subtype of this.
"""
abstract type AbstractInterceptionModel <: AbstractModel end


"""
Energy balance abstract struct. All energy balance models must be a subtype of this.
"""
abstract type AbstractEnergyModel <: AbstractModel end
