"""
    to_initialise(v::T, vars...) where T <: Union{Missing,AbstractModel}
    to_initialise(m::T)  where T <: AbstractComponentModel

Return the variables that must be initialized providing a set of models.

# Note

There is no way to know before-hand which process will be simulated by the user, so if you
have a component with a model for each process, the variables to initialise are always the
smallest subset of all, meaning it is considered the variables needed for models can be
output from other models.

# Examples

```julia
to_initialise(Fvcb(),Medlyn(0.03,12.0))

# Or using a component directly:
leaf = LeafModels(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03,12.0))
to_initialise(leaf)
```
"""
function to_initialise(v::T, vars...) where {T<:AbstractModel}
    setdiff(inputs(v, vars...), outputs(v, vars...))
end

function to_initialise(m::T) where {T<:AbstractComponentModel}
    # These are all the variables needed for a simulation given the models:
    default_values = init_variables(m.models...)

    # These are the ones that we need to initialize before simulation:
    needed_variables = NamedTuple(i => default_values[i] for i in to_initialise(m.models...))
    vars_not_init_(m.status, needed_variables)
end

function to_initialise(m::T) where {T<:Dict{String,AbstractComponentModel}}
    toinit = Dict{String,Vector{Symbol}}()
    for (key, value) in m
        toinit_ = to_initialise(value)

        if length(toinit_) > 0
            push!(toinit, key => toinit_)
        end
    end

    return toinit
end

"""
    init_status!(object::Dict{String,AbstractComponentModel};vars...)
    init_status!(component::AbstractComponentModel;vars...)

Intialise model variables for components with user input.

# Examples

```julia
model = read_model("a-model-file.yml")
init_status!(model, Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = 1.2)
```
"""
function init_status!(object::Dict{String,AbstractComponentModel}; vars...)
    new_vals = (; vars...)

    for (component_name, component) in object
        for j in keys(new_vals)
            if !in(j, keys(component.status))
                @info "Key $j not found as a variable for any provided models in $component_name" maxlog = 1
                continue
            end
            setproperty!(component.status, j, new_vals[j])
        end
    end
end

function init_status!(component::T; vars...) where {T<:AbstractComponentModel}
    new_vals = (; vars...)
    for j in keys(new_vals)
        if !in(j, keys(component.status))
            @info "Key $j not found as a variable for any provided models"
            continue
        end
        setproperty!(component.status, j, new_vals[j])
    end
end

"""
    init_variables(models...)

Intialized model variables with their default values. The variables are taken from the
inputs and outputs of the models.

# Examples

```julia
init_variables(Monteith())
init_variables(Monteith(), Medlyn(0.03,12.0))
init_variables(energy = Monteith(), gs = Medlyn(0.03,12.0))
```
"""
function init_variables(model::T) where {T<:AbstractModel}
    # Only one model is provided:

    in_vars = inputs_(model)
    out_vars = outputs_(model)
    # Merge both:
    vars = merge(in_vars, out_vars)

    return vars
end

# Several models are provided:
function init_variables(models...)
    mods = (models...,)
    in_vars = merge(inputs_.(mods)...)
    out_vars = merge(outputs_.(mods)...)
    # Merge both:
    vars = merge(in_vars, out_vars)

    return vars
end

"""
    instantiate_status_struct(::Type{MutableNamedTuple}, vars)
    instantiate_status_struct(::Type{NamedTuple}, vars)

Instantiate a struct with new values for the status of a model in an homogeneous and
type-stable way.
"""
function instantiate_status_struct(::Type{MutableNamedTuple}, vars)
    MutableNamedTuple{keys(vars)}(values(vars))
end

function instantiate_status_struct(::Type{NamedTuple}, vars)
    NamedTuple{keys(vars)}(values(vars))
end

# Models are provided as keyword arguments:
function init_variables(; kwargs...)
    mods = (values(kwargs)...,)
    init_variables(mods...)
end

"""
    is_initialised(m::T) where T <: AbstractComponentModel
    is_initialised(m::T, models...) where T <: AbstractComponentModel

Check if the variables that must be initialised are, and return `true` if so, and `false` and
an information message if not.

# Note

There is no way to know before-hand which process will be simulated by the user, so if you
have a component with a model for each process, the variables to initialise are always the
smallest subset of all, meaning it is considered the user will simulate the variables needed
for other models.

# Examples

```julia
leaf = ModelList(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03,12.0))
is_initialised(leaf)

# Searching for just a sub-set of models:
is_initialised(leaf,leaf.photosynthesis)
# NB: this is usefull when the leaf is parameterised for all processes but only one is
# simulated, so its inputs must be initialised
```
"""
function is_initialised(m::T; info=true) where {T<:AbstractComponentModel}
    var_names = to_initialise(m)

    if length(var_names) > 0
        info && @info "Some variables must be initialised before simulation: $var_names (see `to_initialise()`)"
        return false
    else
        return true
    end
end

function is_initialised(models...; info=true)
    var_names = to_initialise(models...)
    if length(var_names) > 0
        info && @info "Some variables must be initialised before simulation: $(var_names) (see `to_initialise()`)"
        return false
    else
        return true
    end
end

"""
    vars_not_init_(st<:Status, var_names)

Get which variable is not initialized in the status struct.
"""
function vars_not_init_(status::T, default_values) where {T<:Status}
    length(default_values) == 0 && return () # no variables
    not_init = Symbol[]
    for i in keys(default_values)
        if getproperty(status, i) == default_values[i]
            push!(not_init, i)
        end
    end
    return (not_init...,)
end

# For components with a status with multiple time-steps:
function vars_not_init_(st::T, var_names) where {T<:TimeSteps}
    isnotinit = fill(false, length(var_names))
    for j in st, i in eachindex(var_names)
        if getproperty(j, var_names[i]) == -999.99
            isnotinit[i] = true
        end
    end
    return isnotinit
end

"""
    init_variables_manual(models...;vars...)

Return an initialisation of the model variables with given values.

# Examples

```julia
init_variables_manual(Monteith(); Tₗ = 20.0)
```
"""
function init_variables_manual(status, vars)
    for i in keys(vars)
        !in(i, keys(status)) && error("Key $i not found as a variable of the status.")
        setproperty!(status, i, vars[i])
    end
    status
end
