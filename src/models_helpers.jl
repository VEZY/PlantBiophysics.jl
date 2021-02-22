"""
    variables(::Type)
    variables(::Type, vars...)

Returns a tuple with the name of the output variables of a model, or a union of the output
variables for several models.

# Note

Each model can (and should) have a method for this function.

# Examples

```julia
variables(Monteith())

variables(Monteith(), Medlyn(0.03,12.0))
```
"""
function variables(v::T, vars...) where T <: Union{Missing,AbstractModel}
    # union(variables(v), variables(vars...))
    length((vars...,)) > 0 ? union(variables(v), variables(vars...)) : variables(v)
end

"""
    variables(::Missing)

Returns an empty tuple because missing models do not return any variables.
"""
function variables(v::Missing)
    ()
end

"""
    variables(::AbstractModel)

Returns an empty tuple by default.
"""
function variables(::AbstractModel)
    ()
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
    MutableNamedTuple(; zip(var_names,fill(zero(Float64),length(var_names)))...)
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
