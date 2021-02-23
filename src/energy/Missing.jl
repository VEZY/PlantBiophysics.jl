"""
    net_radiation!(leaf::LeafModels{I,<:Missing,A,Gs,S},meteo::Atmosphere,constants = Constants())

Method for when energy balance is missing (do nothing).

# Arguments

- `leaf::LeafModels{I,<:Missing,A,Gs,S}`: a [`LeafModels`](@ref) struct with a missing energy model.
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

"""
function net_radiation!(leaf::LeafModels{I,<:Missing,A,Gs,S},meteo::Atmosphere,constants = Constants()) where {I,A,Gs,S}
    nothing
end

"""
    net_radiation!(object::Component{I,<:Missing,S},meteo::Atmosphere,constants = Constants())

Method for when energy balance is missing (do nothing).

# Arguments

- `object::Component{I,<:Missing,S}`: a [`Component`](@ref) struct with a missing energy model.
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

"""
function net_radiation!(object::Component{I,<:Missing,S},meteo::Atmosphere,constants = Constants()) where {I,A,Gs,S}
    nothing
end
