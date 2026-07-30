
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
    NamedTuple()
end

function PlantSimEngine.outputs_(::ConstantA)
    (A=-Inf,)
end

PlantSimEngine.output_policy(::Type{<:ConstantA}) = (
    A=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()), # from μmol m-2 s-1 to μmol m-2 timerstep-1
)

Base.eltype(x::ConstantA) = typeof(x).parameters[1]

"""
    run!(model::ConstantA, status, environment, constants=Constants(), context=nothing)

Constant photosynthesis (forcing the value).

# Returns

Modify the leaf status in place for A with a constant value:

- A: carbon assimilation, set to leaf.photosynthesis.A (μmol[CO₂] m-2 s-1)

# Arguments

- `::ConstantA`: a constant assimilation model
- `status`: A status, usually the leaf status (*i.e.* leaf.status)
- `environment`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

# Examples

```julia
using PlantBiophysics, PlantMeteo, PlantSimEngine
environment = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
scene = leaf_scene(ConstantA(26.0); environment=environment)
run!(scene)
only(model_objects(scene; scale=:Leaf)).status.A
```
"""
function PlantSimEngine.run!(model::ConstantA, status, environment, constants=PlantMeteo.Constants(), context=nothing)

    # Net assimilation (μmol m-2 s-1)
    status.A = model.A

    return nothing
end

PlantSimEngine.timestep_hint(::Type{<:ConstantA}) = (
    required=(Dates.Minute(1), Dates.Hour(6)),
    preferred=Dates.Hour(1)
)
