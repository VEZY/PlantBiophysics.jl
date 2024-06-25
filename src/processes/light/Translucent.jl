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
This model is not yet implemented in PlantBiophysics, so it takes the values from the MTG nodes, which means all nodes with the model
should provide the necessary attributes:

- `Ra_SW_f` the absorbed flux of atmospheric radiation in the short wave bandwidth (PAR+NIR), in W m[object]⁻² (== J m[object]⁻² s⁻¹).
- `Ra_PAR_f` the absorbed flux of atmospheric radiation in the PAR bandwidth, in W m[object]⁻² (== J m[object]⁻² s⁻¹).
- `sky_fraction` the sky fraction seen by the the node, in [0, 1].
"""
Base.@kwdef struct Translucent{T} <: AbstractLight_InterceptionModel
    transparency::T = 0.0
    optical_properties::σ = σ()
end

PlantSimEngine.inputs_(::Translucent) = NamedTuple()
PlantSimEngine.outputs_(::Translucent) = (aPPFD=-Inf, Ra_SW_f=-Inf, sky_fraction=-Inf,)

PlantSimEngine.ObjectDependencyTrait(::Type{<:Translucent}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:Translucent}) = PlantSimEngine.IsTimeStepIndependent()

function PlantSimEngine.run!(::Translucent, models, status, meteo, constants, extra=nothing)
    status.Ra_SW_f = status.node.Ra_SW_f[PlantMeteo.rownumber(meteo)]
    status.sky_fraction = status.node.sky_fraction[PlantMeteo.rownumber(meteo)]
    status.aPPFD = status.node.Ra_PAR_f[PlantMeteo.rownumber(meteo)] * 4.57

    return nothing
end