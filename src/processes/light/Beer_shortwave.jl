"""
    BeerShortwave(k, f)
    BeerShortwave(k)

The Beer-Lambert law for light interception for the shortwave radiation.

# Arguments

- `k_PAR`: extinction coefficient for the PAR
- `k_NIR`: extinction coefficient for the NIR, taken equal to the one for the PAR by default

# Required inputs

- `LAI`: the leaf area index (m² m⁻²)
- `Ri_PAR_f`: (from meteorology) the incident flux of atmospheric radiation in the PAR, in W m[soil]⁻² (== J m[soil]⁻² s⁻¹).
- `Ri_NIR_f`: (from meteorology) the incident flux of atmospheric radiation in the NIR, in W m[soil]⁻² (== J m[soil]⁻² s⁻¹).

# Outputs

- `aPPFD`: the absorbed Photosynthetic Photon Flux Density in μmol[PAR] m[leaf]⁻² s⁻¹.
- `Ra_PAR_f`: the absorbed PAR in W m[leaf]⁻².
- `Ra_NIR_f`: the absorbed NIR in W m[leaf]⁻².
- `Ra_SW_f`: the absorbed shortwave radiation in W m[leaf]⁻².

# Examples

```julia
using PlantSimEngine, PlantBiophysics, PlantMeteo

m = ModelList(light_interception=BeerShortwave(0.5), status=(LAI=2.0,))
meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0, Ri_NIR_f=280.0)

run!(m, meteo)

m[:aPPFD]
m[:Ra_SW_f]
m[:Ra_PAR_f]
m[:Ra_NIR_f]
```
"""
struct BeerShortwave{T} <: AbstractLight_InterceptionModel
    k_PAR::T
    k_NIR::T
end

BeerShortwave(k) = BeerShortwave(k, 0.48)
PlantSimEngine.inputs_(::BeerShortwave) = (LAI=-Inf,)
PlantSimEngine.outputs_(::BeerShortwave) = (Ra_SW_f=-Inf, Ra_PAR_f=-Inf, Ra_NIR_f=-Inf, aPPFD=-Inf)
PlantSimEngine.ObjectDependencyTrait(::Type{<:BeerShortwave}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:BeerShortwave}) = PlantSimEngine.IsTimeStepIndependent()

function PlantSimEngine.run!(::BeerShortwave, models, status, meteo, constants, extra)
    status.Ra_PAR_f = meteo.Ri_PAR_f * (1 - exp(-models.light_interception.k_PAR * status.LAI))
    status.Ra_NIR_f = meteo.Ri_NIR_f * (1 - exp(-models.light_interception.k_NIR * status.LAI))
    status.aPPFD = status.Ra_PAR_f * constants.J_to_umol
    status.Ra_SW_f = status.Ra_PAR_f + status.Ra_NIR_f
end
