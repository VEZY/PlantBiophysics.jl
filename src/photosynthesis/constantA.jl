
"""
Constant (forced) assimilation, given in ``μmol\\ m^{-2}\\ s^{-1}``.

# Examples

```julia
ConstantA(30.0)
```
"""
Base.@kwdef struct ConstantA{T} <: AbstractAModel
    A::T = 25.0
end

function inputs(::ConstantA)
    (:Cₛ)
end

function outputs(::ConstantA)
    (:A,:Gₛ)
end

"""
    assimilation!(leaf::LeafModels{I,E,<:ConstantA,<:AbstractGsModel,S},constants = Constants())

Constant photosynthesis.

# Returns

Modify the leaf status in place for A, Gₛ and Cᵢ:

- A: carbon assimilation, set to leaf.photosynthesis.A (μmol[CO₂] m-2 s-1)
- Gₛ: stomatal conductance for CO₂ (mol[CO₂] m-2 s-1)
- Cᵢ: intercellular CO₂ concentration (ppm)

# Arguments

- `leaf::LeafModels{.,.,<:ConstantA,<:AbstractGsModel,.}`: A [`LeafModels`](@ref) struct holding the parameters for
the model with initialisations for:
    - `Cₛ` (mol m-2 s-1): surface CO₂ concentration.
    - `Dₗ` (mol m-2 s-1): vapour pressure difference between the surface and the air saturation
    vapour pressure in case you're using the stomatal conductance model of [`Medlyn`](@ref).
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

# Note

`Cₛ` (and `Dₗ` if you use [`Medlyn`](@ref)) must be initialised by providing them as keyword
arguments (see examples). If in doubt, it is simpler to compute the energy balance of the
leaf with the photosynthesis to get those variables. See [`energy_balance`](@ref) for more
details.

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
leaf = LeafModels(photosynthesis = ConstantA(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            Cₛ = 400.0)

assimilation!(leaf,meteo,Constants())

leaf.status.A
```
"""
function assimilation!(leaf::LeafModels{I,E,<:ConstantA,<:AbstractGsModel,S}, meteo,
    constants = Constants()) where {I,E,S}

    # Net assimilation (μmol m-2 s-1)
    leaf.status.A = leaf.photosynthesis.A

    # Stomatal conductance (mol[CO₂] m-2 s-1)
    leaf.status.Gₛ = gs(leaf,meteo)

    # Intercellular CO₂ concentration (Cᵢ, μmol mol)
    leaf.status.Cᵢ = min(leaf.status.Cₛ, leaf.status.Cₛ - leaf.status.A / leaf.status.Gₛ)

    nothing
end
