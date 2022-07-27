"""
    energy_balance!_(::Missing, models::ModelList, status, meteo::AbstractAtmosphere,constants = Constants())

Method for when energy balance is missing (do nothing).

# Arguments

- `::Missing`: a Missing model.
- `models`: a [`ModelList`](@ref) struct with a missing energy model.
- `status`: the status of the model, usually the one from the models (*i.e.* models.status)
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

"""
function energy_balance!_(::Missing, models, status, meteo::AbstractAtmosphere, constants=Constants())
    nothing
end
