"""
AbstractStatus is the abstract type used for all Status types that store the values of the
variables during simulation.
"""
abstract type AbstractStatus end

"""
    Status(vars)

Status type used to store the values of the variables during simulation.

Fields:

- `vars`: the named variables (e.g. NamedTuple, MutableNamedTuple...)
"""
struct Status <: AbstractStatus
    vars
end

function Base.getproperty(status::Status, key::Symbol)
    getproperty(getfield(status, :vars), key::Symbol)
end

function Base.getproperty(status::Status, i::T) where {T<:Integer}
    getindex(status, i)
end

function Base.setproperty!(status::Status, s::Symbol, x)
    setproperty!(getfield(status, :vars), s, x)
end

# Indexing a Status with an integer returns the status (for compatibility with TimeSteps).
function Base.getindex(status::Status, index::T) where {T<:Integer}
    status
end

function Base.keys(status::Status)
    keys(getfield(status, :vars))
end

# For compatibility with TimeSteps we say Status is length one:
function Base.length(A::Status)
    1
end

Base.eltype(::Type{Status}) = MutableNamedTuple

# Iterate over the status (lenght 1 only) for compatibility with TimeSteps.
Base.iterate(status::Status, i=1) = i > 1 ? nothing : (getfield(status, :vars), i + 1)


"""
    TimeSteps(vars)

TimeSteps is the same than [`Status`](@ref) but for simulation with several time steps.

Fields:

- `ts`: the time steps (e.g. NamedTuple, MutableNamedTuple...)

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
