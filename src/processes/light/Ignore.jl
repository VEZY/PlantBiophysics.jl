"""
Ignore model for light interception, see [here](https://archimed-platform.github.io/archimed-phys-user-doc/3-inputs/5-models/2-models_list/).
Make the mesh invisible, and not computed. Can save a lot of time for the computations when there are components types
that are not visible anyway (e.g. inside others).
"""
struct LightIgnore <: AbstractLight_InterceptionModel end

"""
    run!(::LightIgnore, models::ModelList, status, meteo,constants = Constants())

Method for when light interception should be explicitely ignored (do nothing).

# Arguments

- `::LightIgnore`: an `Ignore` model.
- `models`: a `ModelList` struct with a missing energy model.
- `status`: the status of the model, usually the one from the models (*i.e.* models.status)
- `meteo`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

"""
function PlantSimEngine.run!(::LightIgnore, models, status, meteo, constants=PlantMeteo.Constants(), extra=nothing)
    nothing
end

PlantSimEngine.ObjectDependencyTrait(::Type{<:LightIgnore}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:LightIgnore}) = PlantSimEngine.IsTimeStepIndependent()
