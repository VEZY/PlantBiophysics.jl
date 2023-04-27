
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
    (Cₛ=-Inf,)
end

function PlantSimEngine.outputs_(::ConstantAGs)
    (A=-Inf, Gₛ=-Inf, Cᵢ=-Inf)
end

Base.eltype(x::ConstantAGs) = typeof(x).parameters[1]

"""
    run!(::ConstantAGs, models, status, meteo, constants=Constants())

Constant photosynthesis coupled with a stomatal conductance model.

# Returns

Modify the leaf status in place for A, Gₛ and Cᵢ:

- A: carbon assimilation, set to leaf.photosynthesis.A (μmol[CO₂] m-2 s-1)
- Gₛ: stomatal conductance for CO₂ (mol[CO₂] m-2 s-1)
- Cᵢ: intercellular CO₂ concentration (ppm)

# Arguments

- `::ConstantAGs`: a constant assimilation model coupled to a stomatal conductance model
- `models`: a `ModelList` struct holding the parameters for the model with
initialisations for:
    - `Cₛ` (mol m-2 s-1): surface CO₂ concentration.
    - any other value needed by the stomatal conductance model.
- `status`: A status, usually the leaf status (*i.e.* leaf.status)
- `meteo`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

# Examples

```julia
using PlantBiophysics, PlantMeteo
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
leaf = ModelList(
    photosynthesis = ConstantAGs(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    status = (Cₛ = 400.0, Dₗ = 2.0)
)

run!(leaf,meteo,PlantMeteo.Constants())

status(leaf, :A)
status(leaf, :Cᵢ)
```
"""
function PlantSimEngine.run!(::ConstantAGs, models, status, meteo, constants=PlantMeteo.Constants(), extra=nothing)

    # Net assimilation (μmol m-2 s-1)
    status.A = models.photosynthesis.A

    # Stomatal conductance (mol[CO₂] m-2 s-1)
    PlantSimEngine.run!(models.stomatal_conductance, models, status, meteo, constants, extra)
    # Intercellular CO₂ concentration (Cᵢ, μmol mol)
    status.Cᵢ = min(status.Cₛ, status.Cₛ - status.A / status.Gₛ)

    return nothing
end

PlantSimEngine.ObjectDependencyTrait(::Type{<:ConstantAGs}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:ConstantAGs}) = PlantSimEngine.IsTimeStepIndependent()
