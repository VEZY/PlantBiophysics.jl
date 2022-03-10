"""
    defaults(Type{<:AbstractModel})

Get the default values of a model.

# Examples

```julia
defaults(Fvcb)
```
"""
function defaults(x::T) where {T<:Type{<:AbstractModel}}
    p = x()
    (; (v => getfield(p, v) for v in fieldnames(typeof(p)))...)
end

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

function inputs(v::T, vars...) where {T<:Union{Missing,AbstractModel}}
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

function outputs(v::T, vars...) where {T<:Union{Missing,AbstractModel}}
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
function variables(m::T, ms...) where {T<:Union{Missing,AbstractModel}}
    length((ms...,)) > 0 ? union(variables(m), variables(ms...)) : union(inputs(m), outputs(m))
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
    (; zip(var_names, fill(var_type, length(var_names)))...)
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
                if isdefined(t, i)
                    push!(types_common_vars, t[i])
                end
            end
            push!(var_types_promoted, i => promote_type(types_common_vars...))
        else
            for t in var_types
                if isdefined(t, i)
                    push!(var_types_promoted, i => t[i])
                end
            end
        end
    end

    return (; var_types_promoted...)
end
