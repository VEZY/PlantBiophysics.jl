"""
    status(m)
    status(m::AbstractArray{<:AbstractComponentModel})
    status(m::AbstractDict{T,<:AbstractComponentModel})

Get a ModelList status, *i.e.* the state of the input (and output) variables.

See also [`is_initialised`](@ref) and [`to_initialise`](@ref)
"""
function status(m)
    m.status
end

function status(m::T) where {T<:AbstractArray{<:AbstractComponentModel}}
    [i.status for i in m]
end

function status(m::T) where {T<:AbstractDict{N,<:AbstractComponentModel} where {N}}
    Dict([k => v.status for (k, v) in m])
end

function status(m, key)
    get_status_var(m.status, key)
end

function get_status_var(st::Status, key::Symbol)
    get_status_var(getfield(st, :vars), key)
end

function get_status_var(st::MutableNamedTuples.MutableNamedTuple, key::Symbol)
    getproperty(st, key)
end

function get_status_var(st::MutableNamedTuples.MutableNamedTuple, key)
    getproperty(st, Symbol(key))
end

function get_status_var(st::T, key) where {T<:Vector{MutableNamedTuples.MutableNamedTuple}}
    [getproperty(st_i, Symbol(key)) for st_i in st]
end

# Indexing the status with an integer returns a particular time-step.
# If there is only one time-step, we always return it:
function get_status_var(st::MutableNamedTuples.MutableNamedTuple, i::Integer)
    st
end

# If there are several time-steps, we return the ith:
function get_status_var(st::T, i::Integer) where {T<:Vector{MutableNamedTuples.MutableNamedTuple}}
    st[i]
end


"""
    getindex(component::LeafModels, key::Symbol)
    getindex(component::LeafModels, key)

Indexing a component models structure:
    - with an integer, will return the status at the ith time-step
    - with anything else (Symbol, String) will return the required variable from the status

# Examples

```julia
lm = LeafModels(
    energy_balance = Monteith(),
    photosynthesis = Fvcb(),
    stomatal_conductance = ConstantGs(0.0, 0.0011),
    Cᵢ = 380.0, Tₗ = [20.0, 25.0]
)

lm[:Tₗ] # Returns the value of the Tₗ variable
lm[2]  # Returns the status at the second time-step
lm[2][:Tₗ] # Returns the value of Tₗ at the second time-step
lm[:Tₗ][2] # Equivalent of the above
```
"""
function Base.getindex(component::T, key) where {T<:AbstractComponentModel}
    status(component, key)
end
