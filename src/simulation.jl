"""
    leaf_scene(models...; status=Status(), environment=(duration=Dates.Hour(1),),
               timestep=nothing, type_promotion=nothing, status_transform=nothing)

Build a one-leaf `PlantSimEngine.CompositeModel` using PlantBiophysics model
kernels. The returned scene can be combined with the regular scene/object
inspection and execution APIs.

Hard dependencies declared by the models are resolved on the leaf object.
Use `timestep` to override the application clock for every supplied model.
Use `type_promotion` for scenario-wide status type conversion and
`status_transform` for variable-specific conversion. Both policies are passed
directly to `PlantSimEngine.CompositeModel`.
"""
function _leaf_scene_numeric_prototype(values)
    for value in values
        value isa Number || continue
        value isa Integer && continue
        return value
    end
    return nothing
end

function _leaf_scene_default(default, prototype)
    isnothing(prototype) && return default
    default isa AbstractFloat || return default
    try
        return zero(prototype) + default
    catch
        return default
    end
end

function _leaf_scene_status(status::Status, models)
    status_values = Dict{Symbol,Any}(pairs(NamedTuple(status)))
    prototype = _leaf_scene_numeric_prototype(values(status_values))
    for model in models
        for (variable, initial_value) in pairs(PlantSimEngine.init_variables(model))
            get!(
                status_values,
                Symbol(variable),
                _leaf_scene_default(initial_value, prototype),
            )
        end
    end
    return Status((; status_values...))
end

_leaf_scene_status(status, models) = status

function leaf_scene(
    models::PlantSimEngine.AbstractModel...;
    status=Status(),
    environment=(duration=Dates.Hour(1),),
    timestep=nothing,
    type_promotion=nothing,
    status_transform=nothing,
)
    return PlantSimEngine.CompositeModel(
        models...;
        status=_leaf_scene_status(status, models),
        id=:leaf,
        scale=:Leaf,
        kind=:plant,
        environment=environment,
        timestep=timestep,
        type_promotion=type_promotion,
        status_transform=status_transform,
    )
end
