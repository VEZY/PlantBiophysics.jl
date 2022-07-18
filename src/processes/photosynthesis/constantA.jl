
"""
Constant (forced) assimilation, given in ``μmol\\ m^{-2}\\ s^{-1}``.

See also [`ConstantAGs`](@ref).


# Examples

```julia
ConstantA(30.0)
```
"""
Base.@kwdef struct ConstantA{T} <: AbstractAModel
    A::T = 25.0
end

function inputs(::ConstantA)
    (:A,)
end

function outputs(::ConstantA)
    (:A,)
end

Base.eltype(x::ConstantA) = typeof(x).parameters[1]

"""
    photosynthesis!_(leaf::LeafModels{I,E,<:ConstantA,<:AbstractGsModel,S},constants = Constants())

Constant photosynthesis (forcing the value).

# Returns

Modify the leaf status in place for A with a constant value:

- A: carbon assimilation, set to leaf.photosynthesis.A (μmol[CO₂] m-2 s-1)

# Arguments

- `leaf::LeafModels{.,.,<:ConstantA,.,.}`: A [`LeafModels`](@ref) struct holding the parameters for
the model.
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
leaf = LeafModels(photosynthesis = ConstantA(26.0))

photosynthesis!_(leaf,meteo,Constants())

leaf.status.A
```
"""
function photosynthesis!_(::ConstantA; models, meteo, constants=Constants())

    # Net assimilation (μmol m-2 s-1)
    models.status.A = models.photosynthesis.A

    return nothing
end
