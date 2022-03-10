#! Note: You should always provide a `copy` method for your component models
#! This is just a generic copy for an array or Dict of component models.

"""
    Base.copy(l::AbstractArray{<:AbstractComponentModel})

Copy an array-alike of [`AbstractComponentModel`](@ref)
"""
function Base.copy(l::T) where {T<:AbstractArray{<:AbstractComponentModel}}
    return [copy(i) for i in l]
end

"""
    Base.copy(l::AbstractDict{N,<:AbstractComponentModel} where N)

Copy a Dict-alike [`AbstractComponentModel`](@ref)
"""
function Base.copy(l::T) where {T<:AbstractDict{N,<:AbstractComponentModel} where {N}}
    return Dict([k => v for (k, v) in l])
end
