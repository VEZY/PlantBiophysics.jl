
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

function inputs_(::ConstantA)
    (A=-999.99,)
end

function outputs_(::ConstantA)
    (A=-999.99,)
end

Base.eltype(x::ConstantA) = typeof(x).parameters[1]

"""
    photosynthesis!_(::ConstantA; models, status, meteo, constants=Constants())

Constant photosynthesis (forcing the value).

# Returns

Modify the leaf status in place for A with a constant value:

- A: carbon assimilation, set to leaf.photosynthesis.A (μmol[CO₂] m-2 s-1)

# Arguments

- `::ConstantA`: a constant assimilation model
- `models`: a [`ModelList`](@ref) struct holding the parameters for the model (or <:AbstractComponentModel).
- `status`: A status, usually the leaf status (*i.e.* leaf.status)
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
leaf = ModelList(photosynthesis = ConstantA(26.0))

photosynthesis!_(leaf,meteo,Constants())

leaf.status.A
```
"""
function photosynthesis!_(::ConstantA; models, status, meteo, constants=Constants())

    # Net assimilation (μmol m-2 s-1)
    status.A = models.photosynthesis.A

    return nothing
end
