"""
    BeerShortwave(k, f)
    BeerShortwave(k)

The Beer-Lambert law for light interception that also computes the shortwave radiation as a proportion
of the intercepted photosynthetic photon flux density (PPFD, μmol m-2 s-1).

# Arguments

- `k`: extinction coefficient
- `f=0.48`: proportionality factor between the shortwave radiation and the PPFD (usually 0.48, the default)

# Required inputs

- `LAI`: the leaf area index (m² m⁻²)
- `Ri_PAR_f`: (from meteorology) the incident flux of atmospheric radiation in the PAR, in W m[soil]⁻² (== J m[soil]⁻² s⁻¹).

# Outputs

- `PPFD`: the absorbed Photosynthetic Photon Flux Density in μmol[PAR] m[leaf]⁻² s⁻¹.
- `Rₛ`: the intercepted shortwave radiation in W m[leaf]⁻².

# Examples

```julia
using PlantSimEngine, PlantBiophysics, PlantMeteo

m = ModelList(light_interception=BeerShortwave(0.5), status=(LAI=2.0,))
meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)

run!(m, meteo)

m[:PPFD]
m[:Rₛ]
```
"""
struct BeerShortwave{T} <: AbstractLight_InterceptionModel
    k::T
    f::T
end

BeerShortwave(k) = BeerShortwave(k, 0.48)
PlantSimEngine.inputs_(::BeerShortwave) = (LAI=-Inf,)
PlantSimEngine.outputs_(::BeerShortwave) = (Rₛ=-Inf, PPFD=-Inf)

function PlantSimEngine.run!(::BeerShortwave, models, status, meteo, constants, extra)
    aPAR = meteo.Ri_PAR_f * exp(-models.light_interception.k * status.LAI)
    status.PPFD = aPAR * constants.J_to_umol
    status.Rₛ = aPAR / models.light_interception.f
end
