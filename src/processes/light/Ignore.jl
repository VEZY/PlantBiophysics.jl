"""
Ignore model for light interception, see [here](https://archimed-platform.github.io/archimed-phys-user-doc/3-inputs/5-models/2-models_list/).
Make the mesh invisible, and not computed. Can save a lot of time for the computations when there are components types
that are not visible anyway (e.g. inside others).
"""
struct LightIgnore <: AbstractLight_InterceptionModel end

"""
    run!(::LightIgnore, status, environment, constants=Constants(), context=nothing)

Method for when light interception should be explicitely ignored (do nothing).

# Arguments

- `::LightIgnore`: an `Ignore` model.
- `status`: object state.
- `environment`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

"""
function PlantSimEngine.run!(::LightIgnore, status, environment, constants=PlantMeteo.Constants(), context=nothing)
    nothing
end
