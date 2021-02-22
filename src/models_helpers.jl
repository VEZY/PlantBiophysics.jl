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
    init_variables(vars...)

Intialise model variables based on their instances.

# Examples

```julia
init_variables(Monteith(), Medlyn(0.03,12.0))
```
"""
function init_status!(object::Dict{String,PlantBiophysics.AbstractComponent};vars...)
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
