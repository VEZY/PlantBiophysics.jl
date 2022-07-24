"""
Light interception abstract struct. All light interception models must be a subtype of this.
"""
abstract type AbstractInterceptionModel <: AbstractModel end

"""
Optical properties abstract struct
"""
abstract type OpticalProperties <: AbstractInterceptionModel end
