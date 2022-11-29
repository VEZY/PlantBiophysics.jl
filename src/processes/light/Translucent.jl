"""
Optical properties abstract struct
"""
abstract type OpticalProperties <: AbstractLightModel end

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
Base.@kwdef struct Translucent{T} <: AbstractLightModel
    transparency::T = 0.0
    optical_properties::σ = σ()
end

function PlantSimEngine.inputs_(::Translucent)
    (Rᵢ=-Inf,)
end

function PlantSimEngine.outputs_(::Translucent)
    (
        Rₛ=-Inf, sky_fraction=-Inf
    )
end