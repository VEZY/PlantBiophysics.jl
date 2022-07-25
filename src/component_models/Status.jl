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

function Base.setproperty!(status::Status, s::Symbol, x)
    setproperty!(getfield(status, :vars), s, x)
end

"""
    TimeSteps(vars)

TimeSteps store several [`Status`](@ref) for simulation of several time steps.

Fields:

- `ts`: the time steps (e.g. array of Status)
"""
struct TimeSteps <: AbstractStatus
    ts
end
