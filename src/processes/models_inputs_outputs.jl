"""
    inputs(model::AbstractModel)
    inputs(...)

Get the inputs of one or several models.

Returns an empty tuple by default for `AbstractModel`s (no inputs) or `Missing` models.
"""
function inputs(model::T) where {T<:AbstractModel}
    keys(inputs_(model))
end

function inputs_(model::AbstractModel)
    NamedTuple()
end

function inputs(v::T, vars...) where {T<:AbstractModel}
    length((vars...,)) > 0 ? union(inputs(v), inputs(vars...)) : inputs(v)
end

function inputs_(model::Missing)
    NamedTuple()
end

"""
    outputs(model::AbstractModel)
    outputs(...)

Get the outputs of one or several models.

Returns an empty tuple by default for `AbstractModel`s (no outputs) or `Missing` models.
"""
function outputs(model::T) where {T<:AbstractModel}
    keys(outputs_(model))
end

function outputs(v::T, vars...) where {T<:AbstractModel}
    length((vars...,)) > 0 ? union(outputs(v), outputs(vars...)) : outputs(v)
end

function outputs_(model::AbstractModel)
    NamedTuple()
end

function outputs_(model::Missing)
    NamedTuple()
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
    variables()

Returns a dataframe of all variables in PlantBiophysics, their description and their units.
"""
function variables()
    sort!(CSV.read(joinpath(dirname(dirname(pathof(PlantBiophysics))), "data", "variables.csv"), DataFrame))
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
function variables_typed(m::T) where {T<:AbstractModel}

    in_vars = inputs_(m)
    in_vars_type = Dict(zip(keys(in_vars), typeof(in_vars).types))
    out_vars = outputs_(m)
    out_vars_type = Dict(zip(keys(out_vars), typeof(out_vars).types))

    # Merge both with type promotion:
    vars = mergewith(promote_type, in_vars_type, out_vars_type)

    # Checking that variables have the same type in inputs and outputs:
    vars_different_types = diff_vars(in_vars_type, out_vars_type)
    if length(vars_different_types) > 0
        @warn """The following variables have different types between models:
                    $vars_different_types, they will be promoted."""
    end

    return (; vars...)
end

function variables_typed(m::T, ms...) where {T<:AbstractModel}
    if length((ms...,)) > 0
        m_vars = variables_typed(m)
        ms_vars = variables_typed(ms...)
        m_vars_dict = Dict(zip(keys(m_vars), values(m_vars)))
        ms_vars_dict = Dict(zip(keys(ms_vars), values(ms_vars)))
        vars = mergewith(promote_type, m_vars_dict, ms_vars_dict)
        #! remove the transformation into a Dict when mergewith exist for NamedTuples.
        #! Check here: https://github.com/JuliaLang/julia/issues/36048

        vars_different_types = diff_vars(m_vars, ms_vars)
        if length(vars_different_types) > 0
            @warn """The following variables have different types between models:
            $vars_different_types, they will be promoted."""
        end

        return (; vars...)
    else
        return variables_typed(m)
    end
end

"""
    diff_vars(x, y)

Returns the names of variables that have different values in x and y.
"""
function diff_vars(x, y)
    # Checking that variables have the same value in x and y:
    common_vars = intersect(keys(x), keys(y))
    vars_different_types = []

    if length(common_vars) > 0
        for i in common_vars
            if x[i] != y[i]
                push!(vars_different_types, i)
            end
        end
    end
    return vars_different_types
end
