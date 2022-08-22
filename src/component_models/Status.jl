"""
AbstractStatus is the abstract type used for all Status types that store the values of the
variables during simulation.
"""
abstract type AbstractStatus end

"""
    Status(vars)

Status type used to store the values of the variables during simulation. It is mainly used
as the structure to store the variables in the status field of a [`ModelList`](@ref).

# See also

[`TimeSteps`](@ref) for several time steps.

# Examples

```julia
# A leaf with one value for all variables will make a status with one time step:
leaf = ModelList(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    status=(Tₗ=25.0, PPFD=1000.0, Cₛ=400.0, Dₗ=1.0)
)

# Indexing the model list with a symbol will return the value of the variable:
leaf[:Tₗ]

# Indexing the model list with an integer will always return the first time step, as there
is only one, and because we want a similar interface with TimeSteps:
leaf[1]
```
"""
struct Status{T} <: AbstractStatus where {T}
    vars::T
end

function Base.getproperty(status::Status, key::Symbol)
    @inline getproperty(getfield(status, :vars), key)
end

function Base.setproperty!(status::Status, s::Symbol, x)
    setproperty!(getfield(status, :vars), s, x)
end

# Indexing a Status with an integer returns the status content (for compatibility with TimeSteps).
function Base.getindex(status::Status, index::T) where {T<:Integer}
    getfield(status, :vars)
end

# Indexing with a Symbol extracts the variable (same as getproperty):
function Base.getindex(status::Status, index::Symbol)
    getproperty(status, index)
end

function Base.keys(status::Status)
    keys(getfield(status, :vars))
end

# For compatibility with TimeSteps we say Status is length one:
function Base.length(A::Status)
    1
end

Base.eltype(::Type{Status{T}}) where {T} = T

# Iterate over the status (lenght 1 only) for compatibility with TimeSteps.
Base.iterate(status::Status, i=1) = i > 1 ? nothing : (getfield(status, :vars), i + 1)


"""
    TimeSteps(vars)

TimeSteps is the same than [`Status`](@ref) but for simulation with several time steps. It
is used to store the values of the variables during a simulation, and is mainly used as the
structure in the status field of the [`ModelList`](@ref) type.

# Examples

```julia
# A leaf with several values for at least one of its variable will make a status with
# several time steps:
leaf = ModelList(
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    status=(Tₗ=[25.0, 26.0], PPFD=1000.0, Cₛ=400.0, Dₗ=1.0)
)

# Indexing the model list with an integer will return the first time step:
leaf[1]

# Indexing the model list with a symbol will return the variable with all time steps:
leaf[:Tₗ]

# If you need the value for one variable at one time step, prefer using this (5x faster):
leaf[1].Tₗ

# Rather than this (5x slower):
leaf[:Tₗ][1]
```
"""
struct TimeSteps <: AbstractStatus
    ts
end

# Indexing a TimeSteps object with the dot syntax returns values of all time-steps for a
# variable (e.g. `status.A`).
function Base.getproperty(status::TimeSteps, key::Symbol)
    [getproperty(i, key) for i in getfield(status, :ts)]
end

# Setting the values of a variable in a TimeSteps object is done by indexing the object
# and then providing the values for the variable (must match the length).
function Base.setproperty!(status::TimeSteps, s::Symbol, x)
    @assert length(x) == length(getfield(status, :ts))
    for i in getfield(status, :ts)
        setproperty!(i, s, x)
    end
end

# Indexing a TimeSteps with an integer returns the ith time-step.
function Base.getindex(status::TimeSteps, index::T) where {T<:Integer}
    getfield(status, :ts)[index]
end

# Indexing with a Symbol extracts the variable (same as getproperty):
function Base.getindex(status::TimeSteps, index::Symbol)
    getproperty(status, index)
end

function Base.length(A::TimeSteps)
    length(getfield(A, :ts))
end

Base.eltype(::Type{TimeSteps}) = MutableNamedTuple

# Iterate over all time-steps in a TimeSteps object.
Base.iterate(status::TimeSteps, i=1) = i > length(status) ? nothing : (status[i], i + 1)

# Keys should be the same between TimeSteps so we only need the ones from the first timestep
function Base.keys(status::TimeSteps)
    keys(status[1])
end

# Implements eachindex to iterate over the time-steps; else it would iterate over keys.
Base.eachindex(status::TimeSteps) = 1:length(status)
