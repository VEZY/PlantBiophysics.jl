"""
    DataFrame(components <: AbstractArray{<:AbstractComponentModel})
    DataFrame(components <: AbstractDict{N,<:AbstractComponentModel})

Fetch the data from a [`AbstractComponentModel`](@ref) (or an Array/Dict of) status into
a DataFrame.
"""
function DataFrame(components::T) where {T<:Union{AbstractComponentModel,AbstractArray{<:AbstractComponentModel}}}
    df = DataFrame[]
    for (k, v) in enumerate(components)
        df_c = DataFrame(v)
        df_c[!, :component] .= k
        push!(df, df_c)
    end
    reduce(vcat, df)
end

function DataFrame(components::T) where {T<:AbstractDict{N,<:AbstractComponentModel} where {N}}
    df = DataFrame[]
    for (k, v) in components
        df_c = DataFrame(v)
        df_c[!, :component] .= k
        push!(df, df_c)
    end
    reduce(vcat, df)
end

# NB: could use dispatch on concrete types but would enforce specific implementation for each

function DataFrame(components::T) where {T<:AbstractComponentModel}
    st = status(components)
    if typeof(st) == Vector{MutableNamedTuples.MutableNamedTuple}
        DataFrame([(NamedTuple(j)..., timestep = i) for (i, j) in enumerate(st)])
    else
        DataFrame([NamedTuple(st)])
    end
end
