"""
    energy_balance!_(::Missing, models::ModelList, status, meteo::AbstractAtmosphere,constants = Constants())

Method for when energy balance is missing (do nothing).

# Arguments

- `::Missing`: a Missing model.
- `models`: a `ModelList` struct with a missing energy model.
- `status`: the status of the model, usually the one from the models (*i.e.* models.status)
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

"""
function energy_balance!_(::Missing, models, status, meteo::AbstractAtmosphere, constants=PlantMeteo.Constants(), extra=nothing)
    nothing
end
