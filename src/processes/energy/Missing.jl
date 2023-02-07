"""
    run!(::Missing, models::ModelList, status, meteo,constants = Constants())

Method for when energy balance is missing (do nothing).

# Arguments

- `::Missing`: a Missing model.
- `models`: a `ModelList` struct with a missing energy model.
- `status`: the status of the model, usually the one from the models (*i.e.* models.status)
- `meteo`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

"""
function PlantSimEngine.run!(::Missing, models, status, meteo, constants=PlantMeteo.Constants(), extra=nothing)
    nothing
end
