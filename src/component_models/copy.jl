#! Note: You should always provide a `copy` method for your component models
#! This is just a generic copy for an array or Dict of component models.

"""
    Base.copy(l::AbstractArray{<:ModelList})

Copy an array-alike of [`ModelList`](@ref)
"""
function Base.copy(l::T) where {T<:AbstractArray{<:ModelList}}
    return [copy(i) for i in l]
end

"""
    Base.copy(l::AbstractDict{N,<:ModelList} where N)

Copy a Dict-alike [`ModelList`](@ref)
"""
function Base.copy(l::T) where {T<:AbstractDict{N,<:ModelList} where {N}}
    return Dict([k => v for (k, v) in l])
end
