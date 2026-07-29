"""
    Beer(k)

Beer-Lambert law for light interception.

Required inputs: `LAI` in m² m⁻².
Required meteorology data: `Ri_PAR_f`, the incident flux of atmospheric radiation in the
PAR, in W m[soil]⁻² (== J m[soil]⁻² s⁻¹).

Output: aPPFD, the absorbed Photosynthetic Photon Flux Density in μmol[PAR] m[leaf]⁻² s⁻¹.
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
scene = leaf_scene(Beer(0.5); status=Status(LAI=2.0), environment=environment)
run!(scene)
only(model_objects(scene; scale=:Leaf)).status.aPPFD
```
"""
function PlantSimEngine.run!(model::Beer, status, environment, constants, context=nothing)
    status.aPPFD =
        environment.Ri_PAR_f *
        (1.0 - exp(-model.k * status.LAI)) *
        constants.J_to_umol
end

function PlantSimEngine.inputs_(::Beer)
    (LAI=-Inf,)
end

function PlantSimEngine.outputs_(::Beer)
    (aPPFD=-Inf,)
end

PlantSimEngine.output_policy(::Type{<:Beer}) = (
    aPPFD=PlantSimEngine.Integrate(PlantMeteo.RadiationEnergy()),
)
