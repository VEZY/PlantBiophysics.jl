"""
    inputs(::AbstractModel)

Get the inputs of a model.

Here returns an empty tuple by default for `AbstractModel`s (no inputs).
"""
function inputs(::AbstractModel)
    ()
end

"""
    outputs(::AbstractModel)

Get the outputs of a model.

Returns an empty tuple by default for `AbstractModel`s (no outputs).
"""
function outputs(::AbstractModel)
    ()
end

"""
    variables(::Type)
    variables(::Type, vars...)

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

[`inputs`](@ref) and [`outputs`](@ref) to get only the inputs or outputs of a model.

"""
function variables(v::T, vars...) where T <: Union{Missing,AbstractModel}
    length((vars...,)) > 0 ? union(variables(v), variables(vars...)) : union(inputs(v),outputs(v))
end


function inputs(v::T, vars...) where T <: Union{Missing,AbstractModel}
    length((vars...,)) > 0 ? union(inputs(v), inputs(vars...)) : inputs(v)
end

function outputs(v::T, vars...) where T <: Union{Missing,AbstractModel}
    length((vars...,)) > 0 ? union(outputs(v), outputs(vars...)) : outputs(v)
end

"""
    inputs(::Missing)

Returns an empty tuple because missing models do not need any input variables.
"""
function inputs(v::Missing)
    ()
end

"""
    inputs(::Missing)

Returns an empty tuple because missing models do not compute any variables.
"""
function outputs(v::Missing)
    ()
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
    init_variables(vars...)

Intialise model variables based on their instances.

# Examples

```julia
init_variables(Monteith(), Medlyn(0.03,12.0))
```
"""
function init_variables(models...)
    var_names = variables(models...)
    MutableNamedTuple(; zip(var_names,fill(Float64(-999.99),length(var_names)))...)
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
    init_vars = init_variables(models...)
    new_vals = (;vars...)
    for i in keys(new_vals)
        !in(i,keys(init_vars)) && error("Key $i not found as a variable of any provided models")
        setproperty!(init_vars,i,new_vals[i])
    end
    init_vars
end
