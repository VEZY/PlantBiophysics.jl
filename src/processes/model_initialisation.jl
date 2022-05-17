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
function to_initialise(v::T, vars...) where {T<:Union{Missing,AbstractModel}}
    setdiff(inputs(v, vars...), outputs(v, vars...))
end

function to_initialise(m::T) where {T<:AbstractComponentModel}
    # Get all fields
    models = [getfield(m, x) for x in setdiff(fieldnames(typeof(m)), (:status,))]
    to_init = to_initialise(models...)
    to_init[is_not_init_(m.status, to_init)]
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
    init_variables(models...;types = (Float64,))

Intialise model variables based on their instances. The `types` keyword argument is used to
force a type in the promotion.

# Examples

```julia
init_variables(Monteith(), Medlyn(0.03,12.0))
```
"""
function init_variables(models...; types=(Float64,))
    var_types = promote_type(([i === Any ? Float64 : i for i in eltype.(models)])..., types...)

    vars = variables(models...)
    vars_MNT = MutableNamedTuple(; zip(vars, [var_types(-999.99) for i in vars])...)

    return vars_MNT
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
leaf = LeafModels(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03,12.0))
is_initialised(leaf)

# Searching for just a sub-set of models:
is_initialised(leaf,leaf.photosynthesis)
# NB: this is usefull when the leaf is parameterised for all processes but only one is
# simulated, so its inputs must be initialised
```
"""
function is_initialised(m::T; info=true) where {T<:AbstractComponentModel}
    var_names = to_initialise(m)
    is_not_init = is_not_init_(m.status, var_names)
    if any(is_not_init)
        info && @info "Some variables must be initialised before simulation: $(var_names[is_not_init]) (see `to_initialise()`)"
        return false
    else
        return true
    end
end

function is_initialised(m::T, models...; info=true) where {T<:AbstractComponentModel}
    var_names = to_initialise(models...)
    is_not_init = is_not_init_(m.status, var_names)
    if any(is_not_init)
        info && @info "Some variables must be initialised before simulation: $(var_names[is_not_init]) (see `to_initialise()`)"
        return false
    else
        return true
    end
end

function is_not_init_(st::T, var_names) where {T<:MutableNamedTuple}
    [getproperty(st, i) == -999.99 for i in var_names]
end

# For components with a status with multiple time-steps:
function is_not_init_(st::T, var_names) where {T<:Vector{MutableNamedTuple}}
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
function init_variables_manual(models...; vars...)
    new_vals = (; vars...)
    added_types = (fieldtypes(typeof(new_vals).parameters[2])...,)
    init_vars = init_variables(models...; types=added_types)
    for i in keys(new_vals)
        !in(i, keys(init_vars)) && error("Key $i not found as a variable of any provided models")
        setproperty!(init_vars, i, new_vals[i])
    end
    init_vars
end
