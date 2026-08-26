"""
    Beer(k)

Beer-Lambert law for light interception.

Required inputs: `LAI` in m[leaf]² m[ground]⁻².
Required meteorology data: `Ri_PAR_f`, the incident flux of atmospheric radiation in the
PAR, in W m[ground]⁻² (== J m[ground]⁻² s⁻¹).

Output: `aPPFD`, the canopy-absorbed Photosynthetic Photon Flux Density in
μmol[PAR] m[ground]⁻² s⁻¹. Use [`GroundToMeanLeafPPFD`](@ref) before coupling
this output to a leaf-scale photosynthesis model.
"""
struct Beer{T} <: AbstractLight_InterceptionModel
    k::T
end

"""
    run!(object, environment, constants = Constants())

Computes the light interception of an object using the Beer-Lambert law.

# Arguments

- `::Beer`: a Beer model, from the model list (*i.e.* m.light_interception)
- `status`: leaf state, with `LAI` initialized in m² m⁻².
- `environment`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

# Examples

```julia
using PlantSimEngine, PlantBiophysics, PlantMeteo
environment = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)
scene = CompositeModel(
    Object(:plant; scale=:Plant, status=Status(LAI=2.0));
    applications=(
        ModelSpec(Beer(0.5); name=:canopy_light, on=One(scale=:Plant)),
    ),
    environment=environment,
)
run!(scene)
model_object(scene, :plant).status.aPPFD
```
"""
function PlantSimEngine.run!(model::Beer, status, environment, constants, context=nothing)
    status.aPPFD =
        environment.Ri_PAR_f *
        (1.0 - exp(-model.k * status.LAI)) *
        constants.J_to_umol
end

function PlantSimEngine.inputs_(::Beer)
    (LAI=PlantSimEngine.Required(Real),)
end

PlantSimEngine.environment_inputs_(::Beer) = (Ri_PAR_f=0.0,)

function PlantSimEngine.outputs_(::Beer)
    (aPPFD=-Inf,)
end

PlantSimEngine.variable_contracts_(::Beer) = (
    LAI=LEAF_AREA_INDEX_CONTRACT,
    aPPFD=GROUND_PAR_PHOTON_FLUX_CONTRACT,
)
