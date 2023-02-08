"""
Optical properties abstract struct
"""
abstract type OpticalProperties <: AbstractLight_InterceptionModel end

"""
    σ()
σ, the scattering factor of a component.
See [here](https://archimed-platform.github.io/archimed-phys-user-doc/3-inputs/5-models/2-models_list/#translucent)
for more details
"""
Base.@kwdef struct σ{T} <: OpticalProperties
    PAR::T = 0.15
    NIR::T = 0.9
end


"""
Translucent model for light interception, see [here](https://archimed-platform.github.io/archimed-phys-user-doc//3-inputs/5-models/2-models_list/).
"""
Base.@kwdef struct Translucent{T} <: AbstractLight_InterceptionModel
    transparency::T = 0.0
    optical_properties::σ = σ()
end

function PlantSimEngine.inputs_(::Translucent)
    (Rᵢ=-Inf,)
end

function PlantSimEngine.outputs_(::Translucent)
    # (Rₛ=-Inf, sky_fraction=-Inf)
    # NB, it is not implemented yet so it computes nothing
    NamedTuple()
end

function PlantSimEngine.run!(::Translucent, models, status, meteo, constants, extra=nothing)
    return nothing
end