
"""
    fit(::Type{<:AbstractModel}, df; kwargs)

Optimize the parameters of a model using measurements in `df` and the initialisation values in
`kwargs`. Note that the columns in `df` should match exactly the names and units used in the
model. See particular implementations for more details.
"""
function fit end

# See other files for the implementation of specific model fitting
