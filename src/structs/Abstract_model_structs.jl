"""
Abstract model type. All models are subtypes of this one, see *e.g.* [`AbstractAModel`](@ref)
"""
abstract type AbstractModel end

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
