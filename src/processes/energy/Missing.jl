"""
    energy_balance!_(leaf::LeafModels{I,<:Missing,A,Gs,S},meteo::AbstractAtmosphere,constants = Constants())

Method for when energy balance is missing (do nothing).

# Arguments

- `leaf::LeafModels{I,<:Missing,A,Gs,S}`: a [`LeafModels`](@ref) struct with a missing energy model.
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

"""
function energy_balance!_(::Missing, models, meteo::AbstractAtmosphere, constants=Constants())
    nothing
end
