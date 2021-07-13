"""
    inputs(model::AbstractModel)
    inputs(...)

Get the inputs of one or several models.

Returns an empty tuple by default for `AbstractModel`s (no inputs) or `Missing` models.
"""
function inputs(model::AbstractModel)
    ()
end

function inputs(model::Missing)
    ()
end

function inputs(v::T, vars...) where T <: Union{Missing,AbstractModel}
    length((vars...,)) > 0 ? union(inputs(v), inputs(vars...)) : inputs(v)
end

"""
    outputs(model::AbstractModel)
    outputs(...)

Get the outputs of one or several models.

Returns an empty tuple by default for `AbstractModel`s (no outputs) or `Missing` models.
"""
function outputs(model::AbstractModel)
    ()
end

function outputs(model::Missing)
    ()
end

function outputs(v::T, vars...) where T <: Union{Missing,AbstractModel}
    length((vars...,)) > 0 ? union(outputs(v), outputs(vars...)) : outputs(v)
end

"""
    variables(model)
    variables(model, models...)

Returns a tuple with the name of the variables needed by a model, or a union of those
variables for several models.

# Note

Each model can (and should) have a method for this function.

# Examples

```julia
variables(Monteith())

variables(Monteith(), Medlyn(0.03,12.0))
```

# See also

[`inputs`](@ref), [`outputs`](@ref) and [`variables_typed`](@ref)
"""
function variables(m::T, ms...) where T <: Union{Missing,AbstractModel}
    length((ms...,)) > 0 ? union(variables(m), variables(ms...)) : union(inputs(m),outputs(m))
end

"""
    variables_typed(model)
    variables_typed(model, models...)

Returns a named tuple with the name and the types of the variables needed by a model, or a
union of those for several models.

# Examples

```julia
variables_typed(Monteith())

variables_typed(Monteith(), Medlyn(0.03,12.0))
```

# See also

[`inputs`](@ref), [`outputs`](@ref) and [`variables`](@ref)

"""
function variables_typed(x)
    var_names = variables(x)
    var_type = eltype(x)
    (; zip(var_names, fill(var_type,length(var_names)))...)
end

function variables_typed(ms...)
    var_types = variables_typed.(ms)

    common_variables = intersect(keys.(var_types)...)
    vars_union = union(keys.(var_types)...)


    var_types_promoted = []
    for i in vars_union
        if i in common_variables
            types_common_vars = []

            for t in var_types
                if isdefined(t,i)
                    push!(types_common_vars,t[i])
                end
            end
            push!(var_types_promoted, i => promote_type(types_common_vars...))
        else
            for t in var_types
                if isdefined(t,i)
                    push!(var_types_promoted, i => t[i])
                end
            end
        end
    end

    return (;var_types_promoted...)
end

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
function to_initialise(v::T, vars...) where T <: Union{Missing,AbstractModel}
    setdiff(inputs(v, vars...),outputs(v, vars...))
end

function to_initialise(m::T) where T <: AbstractComponentModel
    # Get al fields
    models = [getfield(m,x) for x in setdiff(fieldnames(typeof(m)),(:status,))]
    to_initialise(models...)
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
function init_status!(object::Dict{String,AbstractComponentModel};vars...)
    new_vals = (;vars...)

    for (component_name,component) in object
        for j in keys(new_vals)
            if !in(j,keys(component.status))
                @info "Key $j not found as a variable for any provided models in $component_name"
                continue
            end
            setproperty!(component.status,j,new_vals[j])
        end
    end
end

function init_status!(component::AbstractComponentModel;vars...)
    new_vals = (;vars...)
    for j in keys(new_vals)
        if !in(j,keys(component.status))
            @info "Key $j not found as a variable for any provided models"
            continue
        end
        setproperty!(component.status,j,new_vals[j])
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
function init_variables(models...; types = (Float64,))
    var_types = promote_type(([i === Any ? Float64 : i for i in eltype.(models)])...,types...)

    vars = variables(models...)
    vars_MNT = MutableNamedTuple(; zip(vars,[var_types(-999.99) for i in vars])...)

    return vars_MNT
end


# function init_variables(models...;all = true)
#     if all
#         var_types = promote_type(([i === Any ? Float64 : i for i in eltype.(models)])...)
#         vars = variables(models...)
#         vars_MNT = MutableNamedTuple(; zip(vars,[var_types(-999.99) for i in vars])...)
#     else
#         var_types = variables_typed(models...)
#         vars_MNT = MutableNamedTuple(; zip(keys(var_types),[i === Any ? Float64(-999.99) : i(-999.99) for i in var_types])...)
#     end

#     return vars_MNT
# end

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
function is_initialised(m::T) where T <: AbstractComponentModel
    var_names = to_initialise(m)
    is_not_init = [getproperty(m.status,i) == -999.99 for i in var_names]
    if any(is_not_init)
        @info "Some variables must be initialised before simulation: $(var_names[is_not_init])"
        return false
    else
        return true
    end
end

function is_initialised(m::T, models...) where T <: AbstractComponentModel
    var_names = to_initialise(models...)
    is_not_init = [getproperty(m.status,i) == -999.99 for i in var_names]
    if any(is_not_init)
        @info "Some variables must be initialised before simulation: $(var_names[is_not_init])"
        return false
    else
        return true
    end
end

"""
    init_variables_manual(models...;vars...)

Return an initialisation of the model variables with given values.

# Examples

```julia
init_variables_manual(Monteith(); Tₗ = 20.0)
```
"""
function init_variables_manual(models...;vars...)

    new_vals = (;vars...)
    added_types = (fieldtypes(typeof(new_vals).parameters[2])...,)
    init_vars = init_variables(models...;types = added_types)
    for i in keys(new_vals)
        !in(i,keys(init_vars)) && error("Key $i not found as a variable of any provided models")
        setproperty!(init_vars,i,new_vals[i])
    end
    init_vars
end


"""
    get_status(component)
    get_status(components::AbstractArray{<:AbstractComponentModel})
    get_status(components::AbstractDict{T,<:AbstractComponentModel})

Get a component status, *i.e.* the state of the input (and output) variables.

See also [`is_initialised`](@ref) and [`to_initialise`](@ref)
"""
function get_status(component)
    component.status
end

function get_status(components::T) where T <: AbstractArray{<:AbstractComponentModel}
    [i.status for i in components]
end

function get_status(components::T) where {T <: AbstractDict{N,<:AbstractComponentModel} where N}
    Dict([k => v.status for (k, v) in components])
end

"""
    DataFrame(components <: AbstractArray{<:AbstractComponentModel})
    DataFrame(components <: AbstractDict{N,<:AbstractComponentModel})

Transform an array of components (or dict-alike) into a DataFrame of their status (and name
for Dicts).
"""
function DataFrame(components::T) where T <: AbstractArray{<:AbstractComponentModel}
    DataFrame([NamedTuple(i) for i in get_status(components)])
end

function DataFrame(components::T) where {T <: AbstractDict{N,<:AbstractComponentModel} where N}
    DataFrame([(NamedTuple(v)..., component = k) for (k, v) in get_status(components)])
end
