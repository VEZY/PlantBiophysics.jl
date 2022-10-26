"""
    Status(vars)

Status type used to store the values of the variables during simulation. It is mainly used
as the structure to store the variables in the [`TimeStepRow`](@ref) of a [`TimeStepTable`](@ref) of a [`ModelList`](@ref).

Most of the code is taken from MasonProtter/MutableNamedTuples.jl, so `Status` is a MutableNamedTuples with a few modifications,
so in essence, it is a stuct that stores a `NamedTuple` of the references to the values of the variables, which makes it mutable.

# Examples

```julia
# A leaf with one value for all variables will make a status with one time step:
st = Status(Rₛ=13.747, sky_fraction=1.0, d=0.03, PPFD=1500.0)

# Indexing a Status with a symbol returns the value of the variable:
st[:Tₗ]

# Indexing the Status with an integer returns the value of the variable by position:
st[1]
```
"""
struct Status{N,T<:Tuple{Vararg{<:Ref}}}
    vars::NamedTuple{N,T}
end

Status(; kwargs...) = Status(NamedTuple{keys(kwargs)}(Ref.(values(values(kwargs)))))
function Status{names}(tuple::Tuple) where {names}
    Status(NamedTuple{names}(Ref.(tuple)))
end

Base.keys(::Status{names}) where {names} = names
Base.values(st::Status) = getindex.(values(getfield(st, :vars)))
refvalues(mnt::Status) = values(getfield(mnt, :vars))
Base.NamedTuple(mnt::Status) = NamedTuple{keys(mnt)}(values(mnt))
Base.Tuple(mnt::Status) = values(mnt)

function Base.show(io::IO, mnt::Status{names}) where {names}
    print(io, "Status", NamedTuple(mnt))
end

Base.getproperty(mnt::Status, s::Symbol) = getproperty(NamedTuple(mnt), s)
#! Shouldn't it be `getproperty(getfield(mnt, :vars), s)[]` instead ? 

function Base.setproperty!(mnt::Status, s::Symbol, x)
    nt = getfield(mnt, :vars)
    getfield(nt, s)[] = x
end
#! And if so, this one should just work with `mnt[s] = x`. 

function Base.setproperty!(mnt::Status, i::Int, x)
    nt = getfield(mnt, :vars)
    getindex(nt, i)[] = x
end
#! And if so, this one should just work with `mnt[i] = x`. 

Base.propertynames(::Status{T,R}) where {T,R} = T
Base.length(mnt::Status) = length(getfield(mnt, :vars))
Base.eltype(::Type{Status{T}}) where {T} = T

Base.iterate(mnt::Status, iter=1) = iterate(NamedTuple(mnt), iter)
#! Idem, shouldn't it be `iterate(getfield(mnt, :vars), iter)` instead ? 

Base.firstindex(mnt::Status) = 1
Base.lastindex(mnt::Status) = lastindex(NamedTuple(mnt))
#! Idem, shouldn't it be `lastindex(getfield(mnt, :vars))` instead ? 

Base.getindex(mnt::Status, i::Int) = getfield(NamedTuple(mnt), i)
#! Idem, shouldn't it be `getfield(getfield(mnt, :vars), i)` instead ? 

Base.getindex(mnt::Status, i::Symbol) = getfield(NamedTuple(mnt), i)
#! Idem, shouldn't it be `getfield(getfield(mnt, :vars), i)` instead ? 

function Base.indexed_iterate(mnt::Status, i::Int, state=1)
    Base.indexed_iterate(NamedTuple(mnt), i, state)
end
#! Idem, shouldn't it be `Base.indexed_iterate(getfield(mnt, :vars), i, state)` instead ? 