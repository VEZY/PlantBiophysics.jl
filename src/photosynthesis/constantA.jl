
"""
Constant (forced) assimilation, given in ``\mu mol\\ m^{-2}\\ s^{-1}``.

# Examples

```julia
ConstantA(30.0)
```
"""
Base.@kwdef struct ConstantA{T} <: AModel
    A::T = 25.0
end

function variables(::ConstantA)
    (:A,:Gₛ,:Cᵢ,:Cₛ)
end

"""
    assimilation!(leaf::Leaf{G,I,E,<:ConstantA,<:GsModel,S},constants = Constants())

Constant photosynthesis.

# Returns

Modify the leaf status in place for A, Gₛ and Cᵢ:

- A: carbon assimilation, set to leaf.photosynthesis.A (μmol[CO₂] m-2 s-1)
- Gₛ: stomatal conductance for CO₂ (mol[CO₂] m-2 s-1)
- Cᵢ: intercellular CO₂ concentration (ppm)

# Arguments

- `leaf::Leaf{.,.,.,<:Fvcb,<:GsModel,.}`: A [`Leaf`](@ref) struct holding the parameters for
the model
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
leaf = Leaf(photosynthesis = ConstantA(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            Cₛ = 400.0)

assimilation!(leaf,meteo,Constants())

leaf.status.A
```
"""
function assimilation!(leaf::Leaf{G,I,E,<:ConstantA,<:GsModel,S}, meteo, constants = Constants()) where {G,I,E,S}

    # Net assimilation (μmol m-2 s-1)
    leaf.status.A = leaf.photosynthesis.A

    # Stomatal conductance (mol[CO₂] m-2 s-1)
    leaf.status.Gₛ = gs(leaf,meteo)

    # Intercellular CO₂ concentration (Cᵢ, μmol mol)
    if leaf.status.Gₛ > 0.0 && leaf.status.A > 0.0
        leaf.status.Cᵢ = leaf.status.Cₛ - leaf.status.A / leaf.status.Gₛ
    else
        leaf.status.Cᵢ = leaf.status.Cₛ
    end
    nothing
end
