"""
    to_initialize(v::T, vars...) where T <: Union{Missing,AbstractModel}
    to_initialize(m::T)  where T <: ModelList

Return the variables that must be initialized providing a set of models and processes. The
function takes into account model coupling and only returns the variables that are needed
considering that some variables that are outputs of some models are used as inputs of others.

# Examples

```julia
to_initialize(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03,12.0))

# Or using a component directly:
leaf = ModelList(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03,12.0))
to_initialize(leaf)
```
"""
function to_initialize(m::ModelList; verbose::Bool=true)
    needed_variables = to_initialize(dep(m; verbose=verbose))
    to_init = Dict{Symbol,Tuple}()
    for (process, vars) in pairs(needed_variables)
        not_init = vars_not_init_(m.status, vars)
        length(not_init) > 0 && push!(to_init, process => not_init)
    end
    return NamedTuple(to_init)
end

function to_initialize(m::DependencyTree)
    dependencies = Dict{Symbol,NamedTuple}()
    for (process, root) in m.roots
        push!(dependencies, process => to_initialize(root))
    end

    return NamedTuple(dependencies)
end

function to_initialize(m::DependencyNode)
    computed_above = Dict{Symbol,Any}()
    need_initialisations = Dict{Symbol,Any}()
    for i in AbstractTrees.PreOrderDFS(m)
        merge!(computed_above, pairs(i.outputs))

        for (k, v) in pairs(i.inputs)
            if !in(k, keys(computed_above))
                push!(need_initialisations, k => v)
            end
        end
    end

    return NamedTuple(need_initialisations)
end

function to_initialize(m::T) where {T<:Dict{String,ModelList}}
    toinit = Dict{String,NamedTuple}()
    for (key, value) in m
        # key = "Leaf"; value = m[key]
        toinit_ = to_initialize(value)

        if length(toinit_) > 0
            push!(toinit, key => toinit_)
        end
    end

    return toinit
end


function to_initialize(; verbose=true, vars...)
    needed_variables = to_initialize(dep(; verbose=verbose, (; vars...)...))
    to_init = Dict{Symbol,Tuple}()
    for (process, vars) in pairs(needed_variables)
        not_init = keys(vars)
        length(not_init) > 0 && push!(to_init, process => not_init)
    end
    return NamedTuple(to_init)
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
init_variables(energy_balance = Monteith(), stomatal_conductance = Medlyn(0.03,12.0))
```
"""
function init_variables(model::T; verbose::Bool=true) where {T<:AbstractModel}
    # Only one model is provided:
    in_vars = inputs_(model)
    out_vars = outputs_(model)
    # Merge both:
    vars = merge(in_vars, out_vars)

    return vars
end

function init_variables(m::ModelList; verbose::Bool=true)
    init_variables(dep(m; verbose=verbose))
end

function init_variables(m::DependencyTree)
    dependencies = Dict{Symbol,NamedTuple}()
    for (process, root) in m.roots
        push!(dependencies, process => init_variables(root))
    end

    return NamedTuple(dependencies)
end

function init_variables(m::DependencyNode)
    inputs_all = Dict{Symbol,Any}()
    outputs_all = Dict{Symbol,Any}()
    for i in AbstractTrees.PreOrderDFS(m)
        merge!(outputs_all, pairs(i.outputs))

        merge!(inputs_all, pairs(i.inputs))
    end

    all_vars = merge(inputs_all, outputs_all)
    return NamedTuple(all_vars)
end

# Models are provided as keyword arguments:
function init_variables(; verbose::Bool=true, kwargs...)
    mods = (; kwargs...)
    init_variables(dep(; verbose=verbose, mods...))
end

# Models are provided as a NamedTuple:
function init_variables(models::T; verbose::Bool=true) where {T<:NamedTuple}
    init_variables(dep(; verbose=verbose, models...))
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
```
"""
function is_initialized(m::T; verbose=true) where {T<:ModelList}
    var_names = to_initialize(m; verbose=verbose)

    if any([length(to_init) > 0 for (process, to_init) in pairs(var_names)])
        verbose && @info "Some variables must be initialized before simulation: $var_names (see `to_initialize()`)"
        return false
    else
        return true
    end
end

function is_initialized(models...; verbose=true)
    var_names = to_initialize(models...)
    if length(var_names) > 0
        verbose && @info "Some variables must be initialized before simulation: $(var_names) (see `to_initialize()`)"
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
