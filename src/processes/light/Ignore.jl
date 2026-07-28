"""
Ignore model for light interception, see [here](https://archimed-platform.github.io/archimed-phys-user-doc/3-inputs/5-models/2-models_list/).
Make the mesh invisible, and not computed. Can save a lot of time for the computations when there are components types
that are not visible anyway (e.g. inside others).
"""
struct LightIgnore <: AbstractLight_InterceptionModel end

"""
    run!(::LightIgnore, models, status, meteo, constants=Constants(), extra=nothing)

Method for when light interception should be explicitely ignored (do nothing).

# Arguments

- `::LightIgnore`: an `Ignore` model.
- `models`: the compiled model bundle for the application.
- `status`: object state.
- `meteo`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

"""
function PlantSimEngine.run!(::LightIgnore, models, status, meteo, constants=PlantMeteo.Constants(), extra=nothing)
    nothing
end
