"""
    BeerShortwave(k_PAR, k_NIR)
    BeerShortwave(k)

The Beer-Lambert law for light interception for the shortwave radiation.

# Arguments

- `k_PAR`: extinction coefficient for the PAR
- `k_NIR`: extinction coefficient for the NIR. The one-argument constructor
  preserves the historical default `k_NIR = 0.48`; pass both coefficients to
  choose another NIR value.

# Required inputs

- `LAI`: the leaf area index (m[leaf]² m[ground]⁻²)
- `Ri_PAR_f`: (from meteorology) the incident flux of atmospheric radiation in the PAR, in W m[ground]⁻² (== J m[ground]⁻² s⁻¹).
- `Ri_NIR_f`: (from meteorology) the incident flux of atmospheric radiation in the NIR, in W m[ground]⁻² (== J m[ground]⁻² s⁻¹).

# Outputs

- `aPPFD`: canopy-absorbed Photosynthetic Photon Flux Density in
  μmol[PAR] m[ground]⁻² s⁻¹.
- `Ra_PAR_f`: canopy-absorbed PAR in W m[ground]⁻².
- `Ra_NIR_f`: canopy-absorbed NIR in W m[ground]⁻².
- `Ra_SW_f`: canopy-absorbed shortwave radiation in W m[ground]⁻².

Use [`GroundToMeanLeafPPFD`](@ref) and
[`GroundToMeanLeafShortwave`](@ref) before coupling these canopy outputs to
leaf-scale physiology models.

# Examples

```julia
using PlantSimEngine, PlantBiophysics, PlantMeteo

environment = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0, Ri_NIR_f=280.0)
scene = CompositeModel(
    Object(:plant; scale=:Plant, status=Status(LAI=2.0));
    applications=(
        ModelSpec(BeerShortwave(0.5); name=:canopy_light, on=One(scale=:Plant)),
    ),
    environment=environment,
)
run!(scene)
plant = model_object(scene, :plant)
(plant.status.aPPFD, plant.status.Ra_SW_f, plant.status.Ra_PAR_f, plant.status.Ra_NIR_f)
```
"""
struct BeerShortwave{T} <: AbstractLight_InterceptionModel
    k_PAR::T
    k_NIR::T
end

BeerShortwave(k) = BeerShortwave(k, 0.48)
PlantSimEngine.inputs_(::BeerShortwave) = (LAI=PlantSimEngine.Required(Real),)
PlantSimEngine.environment_inputs_(::BeerShortwave) = (Ri_PAR_f=0.0, Ri_NIR_f=0.0)
PlantSimEngine.outputs_(::BeerShortwave) = (Ra_SW_f=-Inf, Ra_PAR_f=-Inf, Ra_NIR_f=-Inf, aPPFD=-Inf)
# PAR- and NIR-only diagnostics deliberately remain uncontracted: the current
# contract vocabulary has no spectral-band field, so giving them the shortwave
# contract would allow either component to be renamed into `Ra_SW_f`.
PlantSimEngine.variable_contracts_(::BeerShortwave) = (
    LAI=LEAF_AREA_INDEX_CONTRACT,
    Ra_SW_f=GROUND_IRRADIANCE_CONTRACT,
    aPPFD=GROUND_PAR_PHOTON_FLUX_CONTRACT,
)
function PlantSimEngine.run!(model::BeerShortwave, status, environment, constants, context)
    status.Ra_PAR_f = environment.Ri_PAR_f * (1.0 - exp(-model.k_PAR * status.LAI))
    status.Ra_NIR_f = environment.Ri_NIR_f * (1.0 - exp(-model.k_NIR * status.LAI))
    status.aPPFD = status.Ra_PAR_f * constants.J_to_umol
    status.Ra_SW_f = status.Ra_PAR_f + status.Ra_NIR_f
end
