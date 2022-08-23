"""
    status(m)
    status(m::AbstractArray{<:ModelList})
    status(m::AbstractDict{T,<:ModelList})

Get a ModelList status, *i.e.* the state of the input (and output) variables.

See also [`is_initialized`](@ref) and [`to_initialize`](@ref)
"""
function status(m)
    m.status
end

function status(m::T) where {T<:AbstractArray{M} where {M}}
    [status(i) for i in m]
end

function status(m::T) where {T<:AbstractDict{N,M} where {N,M}}
    Dict([k => status(v) for (k, v) in m])
end

# Status with a variable would return the variable value.
function status(m, key::Symbol)
    getproperty(m.status, key)
end

# Status with an integer returns the ith status.
function status(m, key::T) where {T<:Integer}
    getindex(m.status, key)
end

"""
    getindex(component<:ModelList, key::Symbol)
    getindex(component<:ModelList, key)

Indexing a component models structure:
    - with an integer, will return the status at the ith time-step
    - with anything else (Symbol, String) will return the required variable from the status

# Examples

```julia
lm = ModelList(
    energy_balance = Monteith(),
    photosynthesis = Fvcb(),
    stomatal_conductance = ConstantGs(0.0, 0.0011),
    status = (Cᵢ = 380.0, Tₗ = [20.0, 25.0])
)

lm[:Tₗ] # Returns the value of the Tₗ variable
lm[2]  # Returns the status at the second time-step
lm[2][:Tₗ] # Returns the value of Tₗ at the second time-step
lm[:Tₗ][2] # Equivalent of the above
```
"""
function Base.getindex(component::T, key) where {T<:ModelList}
    status(component, key)
end

function Base.setindex!(component::T, value, key) where {T<:ModelList}
    setproperty!(status(component), key, value)
end
