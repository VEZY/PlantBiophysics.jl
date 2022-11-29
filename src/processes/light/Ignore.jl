"""
Ignore model for light interception, see [here](https://archimed-platform.github.io/archimed-phys-user-doc/3-inputs/5-models/2-models_list/).
Make the mesh invisible, and not computed. Can save a lot of time for the computations when there are components types
that are not visible anyway (e.g. inside others).
"""
struct Ignore <: AbstractLightModel end

"""
    light_interception!_(::Ignore, models::ModelList, status, meteo::PlantMeteo.AbstractAtmosphere,constants = Constants())

Method for when light interception should be explicitely ignored (do nothing).

# Arguments

- `::Ignore`: an `Ignore` model.
- `models`: a [`ModelList`](@ref) struct with a missing energy model.
- `status`: the status of the model, usually the one from the models (*i.e.* models.status)
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = PlantMeteo.Constants()`: physical constants. See [`Constants`](@ref) for more details

"""
function energy_balance!_(::Ignore, models, status, meteo::PlantMeteo.AbstractAtmosphere, constants=PlantMeteo.Constants(), extra=nothing)
    nothing
end
