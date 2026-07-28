"""
    leaf_scene(models...; status=Status(), environment=(duration=Dates.Hour(1),), timestep=nothing)

Build a one-leaf `PlantSimEngine.CompositeModel` using PlantBiophysics model
kernels. The returned scene can be combined with the regular scene/object
inspection and execution APIs.

Hard dependencies declared by the models are resolved on the leaf object.
Use `timestep` to override the application clock for every supplied model.
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
        for (variable, default) in pairs(PlantSimEngine.inputs_(model))
            get!(status_values, Symbol(variable), _leaf_scene_default(default, prototype))
        end
        for (variable, default) in pairs(PlantSimEngine.outputs_(model))
            get!(status_values, Symbol(variable), _leaf_scene_default(default, prototype))
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
)
    return PlantSimEngine.CompositeModel(
        models...;
        status=_leaf_scene_status(status, models),
        id=:leaf,
        scale=:Leaf,
        kind=:plant,
        environment=environment,
        timestep=timestep,
    )
end
