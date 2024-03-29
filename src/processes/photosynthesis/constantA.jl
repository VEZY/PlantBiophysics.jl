
"""
Constant (forced) assimilation, given in ``μmol\\ m^{-2}\\ s^{-1}``.

See also [`ConstantAGs`](@ref).


# Examples

```julia
ConstantA(30.0)
```
"""
Base.@kwdef struct ConstantA{T} <: AbstractPhotosynthesisModel
    A::T = 25.0
end

function PlantSimEngine.inputs_(::ConstantA)
    (A=-Inf,)
end

function PlantSimEngine.outputs_(::ConstantA)
    (A=-Inf,)
end

Base.eltype(x::ConstantA) = typeof(x).parameters[1]

"""
    run!(::ConstantA; models, status, meteo, constants=Constants())

Constant photosynthesis (forcing the value).

# Returns

Modify the leaf status in place for A with a constant value:

- A: carbon assimilation, set to leaf.photosynthesis.A (μmol[CO₂] m-2 s-1)

# Arguments

- `::ConstantA`: a constant assimilation model
- `models`: a `ModelList` struct holding the parameters for the model.
- `status`: A status, usually the leaf status (*i.e.* leaf.status)
- `meteo`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
leaf = ModelList(photosynthesis = ConstantA(26.0))

run!(leaf,meteo,Constants())

leaf.status.A
```
"""
function PlantSimEngine.run!(::ConstantA, models, status, meteo, constants=PlantMeteo.Constants(), extra=nothing)

    # Net assimilation (μmol m-2 s-1)
    status.A = models.photosynthesis.A

    return nothing
end

PlantSimEngine.ObjectDependencyTrait(::Type{<:ConstantA}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:ConstantA}) = PlantSimEngine.IsTimeStepIndependent()

