"""
    to_initialize(v::T, vars...) where T <: Union{Missing,AbstractModel}
    to_initialize(m::T)  where T <: ModelList

Return the variables that must be initialized providing a set of models.

# Note

There is no way to know before-hand which process will be simulated by the user, so if you
have a component with a model for each process, the variables to initialize are always the
smallest subset of all, meaning it is considered the variables needed for models can be
output from other models.

# Examples

```julia
to_initialize(Fvcb(),Medlyn(0.03,12.0))

# Or using a component directly:
leaf = ModelList(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03,12.0))
to_initialize(leaf)
```
"""
function to_initialize(v::T, vars...) where {T<:AbstractModel}
    Tuple(setdiff(inputs(v, vars...), outputs(v, vars...)))
end

function to_initialize(m::T) where {T<:ModelList}
    # These are all the variables needed for a simulation given the models:
    default_values = init_variables(m.models...)

    # These are the ones that we need to initialize before simulation:
    needed_variables = NamedTuple(i => default_values[i] for i in to_initialize(m.models...))
    vars_not_init_(m.status, needed_variables)
end

function to_initialize(m::T) where {T<:Dict{String,ModelList}}
    toinit = Dict{String,Tuple{Vararg{Symbol}}}()
    for (key, value) in m
        # key = "Leaf"; value = m[key]
        toinit_ = to_initialize(value)

        if length(toinit_) > 0
            push!(toinit, key => toinit_)
        end
    end

    return toinit
end

"""
    init_status!(object::Dict{String,ModelList};vars...)
    init_status!(component::ModelList;vars...)

Intialise model variables for components with user input.

# Examples

```julia
model = read_model("a-model-file.yml")
init_status!(model, Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = 1.2)
```
"""
function init_status!(object::Dict{String,ModelList}; vars...)
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

function init_status!(component::T; vars...) where {T<:ModelList}
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

# Models are provided as keyword arguments:
function init_variables(; kwargs...)
    mods = (values(kwargs)...,)
    init_variables(mods...)
end

"""
    convert_status(T, x)
    convert_status(::Type{MutableNamedTuple}, x)

Convert a type into another type.

The generic method simply uses `convert(T, x)`. This function is used to convert the status
often given as a `NamedTuple` into the desired type, by default a `MutableNamedTuple`.

We need to override this method for any other type we would need for the status.

Note: we implement this function to avoid type piracy, *i.e.* implementing generic functions
for types we don't own.
"""
function convert_status(::Type{T}, x) where {T}
    convert(T, x)
end

function convert_status(::Type{MutableNamedTuple}, x::T) where {T<:NamedTuple}
    MutableNamedTuple{keys(x)}(values(x))
end

function convert_status(::Type{NamedTuple}, x::T) where {T<:MutableNamedTuple}
    NamedTuple{keys(x)}(values(x))
end

"""
    merge_status(::Type{MutableNamedTuple}, x, y)
    merge_status(::Type{NamedTuple}, x, y)

Merge two status.

The generic version simply uses `merge`. We use `merge_status` so we can implement merge for
types we don't own, avoiding type piracy.
"""
function merge_status(x, y)
    merge(x, y)
end

function merge_status(x::MutableNamedTuple, y::MutableNamedTuple)
    z = merge(NamedTuple(x), NamedTuple(y))
    return MutableNamedTuple{keys(z)}(values(z))
end

"""
    is_initialized(m::T) where T <: ModelList
    is_initialized(m::T, models...) where T <: ModelList

Check if the variables that must be initialized are, and return `true` if so, and `false` and
an information message if not.

# Note

There is no way to know before-hand which process will be simulated by the user, so if you
have a component with a model for each process, the variables to initialize are always the
smallest subset of all, meaning it is considered the user will simulate the variables needed
for other models.

# Examples

```julia
leaf = ModelList(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03,12.0))
is_initialized(leaf)

# Searching for just a sub-set of models:
is_initialized(leaf,leaf.photosynthesis)
# NB: this is usefull when the leaf is parameterised for all processes but only one is
# simulated, so its inputs must be initialized
```
"""
function is_initialized(m::T; info=true) where {T<:ModelList}
    var_names = to_initialize(m)

    if length(var_names) > 0
        info && @info "Some variables must be initialized before simulation: $var_names (see `to_initialize()`)"
        return false
    else
        return true
    end
end

function is_initialized(models...; info=true)
    var_names = to_initialize(models...)
    if length(var_names) > 0
        info && @info "Some variables must be initialized before simulation: $(var_names) (see `to_initialize()`)"
        return false
    else
        return true
    end
end

"""
    vars_not_init_(st<:Status, var_names)

Get which variable is not properly initialized in the status struct.
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
function vars_not_init_(status::T, default_values) where {T<:TimeSteps}
    length(default_values) == 0 && return () # no variables

    not_init = Set{Symbol}()
    for st in status, i in eachindex(default_values)
        if getproperty(st, i) == getproperty(default_values, i)
            push!(not_init, i)
        end
    end

    return Tuple(not_init)
end

"""
    init_variables_manual(models...;vars...)

Return an initialisation of the model variables with given values.

# Examples

```julia
init_variables_manual(status, (Tₗ = 20.0,))
```
"""
function init_variables_manual(status, vars)
    for i in keys(vars)
        !in(i, keys(status)) && error("Key $i not found as a variable of the status.")
        setproperty!(status, i, vars[i])
    end
    status
end
