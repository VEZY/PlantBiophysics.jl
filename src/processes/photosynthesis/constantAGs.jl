
"""
Constant (forced) assimilation, given in ``μmol\\ m^{-2}\\ s^{-1}``,
coupled with a stomatal conductance model that helps computing Cᵢ.

# Examples

```julia
ConstantAGs(30.0)
```
"""
Base.@kwdef struct ConstantAGs{T} <: AbstractPhotosynthesisModel
    A::T = 25.0
end

function PlantSimEngine.inputs_(::ConstantAGs)
    (Cₛ=PlantSimEngine.Required(Real),)
end

function PlantSimEngine.outputs_(::ConstantAGs)
    (A=-Inf, Gₛ=-Inf, Cᵢ=-Inf)
end

PlantSimEngine.dep(::ConstantAGs) = (
    stomatal_conductance=PlantSimEngine.Call(
        PlantSimEngine.One(scale=:Leaf, process=:stomatal_conductance),
    ),
)

PlantSimEngine.output_policy(::Type{<:ConstantAGs}) = (
    A=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()), # from μmol m-2 s-1 to μmol m-2 timerstep-1
    Cᵢ=PlantSimEngine.Integrate(PlantMeteo.MeanReducer()),
    Gₛ=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()),
)

Base.eltype(x::ConstantAGs) = typeof(x).parameters[1]

"""
    run!(model::ConstantAGs, status, environment, constants=Constants(), context=nothing)

Constant photosynthesis coupled with a stomatal conductance model.

# Returns

Modify the leaf status in place for A, Gₛ and Cᵢ:

- A: carbon assimilation, set to leaf.photosynthesis.A (μmol[CO₂] m-2 s-1)
- Gₛ: stomatal conductance for CO₂ (mol[CO₂] m-2 s-1)
- Cᵢ: intercellular CO₂ concentration (ppm)

# Arguments

- `::ConstantAGs`: a constant assimilation model coupled to a stomatal conductance model
- The declared stomatal-conductance call target shares status initialisations for:
    - `Cₛ` (mol m-2 s-1): surface CO₂ concentration.
    - any other value needed by the stomatal conductance model.
- `status`: A status, usually the leaf status (*i.e.* leaf.status)
- `environment`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

# Examples

```julia
using PlantBiophysics, PlantMeteo, PlantSimEngine
environment = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
scene = leaf_scene(
    ConstantAGs(),
    Medlyn(0.03, 12.0);
    status=Status(Cₛ=400.0, Dₗ=2.0),
    environment=environment,
)
run!(scene)
leaf = only(model_objects(scene; scale=:Leaf))
(leaf.status.A, leaf.status.Cᵢ)
```
"""
function PlantSimEngine.run!(model::ConstantAGs, status, environment, constants=PlantMeteo.Constants(), context=nothing)

    # Net assimilation (μmol m-2 s-1)
    status.A = model.A

    # Stomatal conductance (mol[CO₂] m-2 s-1)
    # ConstantAGs owns Gₛ; the stomatal model updates the shared trial status only.
    PlantSimEngine.run_call!(
        context,
        :stomatal_conductance;
        sampled_environment=environment,
        publish=false,
    )
    # Intercellular CO₂ concentration (Cᵢ, μmol mol)
    status.Cᵢ = min(status.Cₛ, status.Cₛ - status.A / status.Gₛ)

    return nothing
end

PlantSimEngine.timestep_hint(::Type{<:ConstantAGs}) = (
    required=(Dates.Minute(1), Dates.Hour(6)),
    preferred=Dates.Hour(1)
)
