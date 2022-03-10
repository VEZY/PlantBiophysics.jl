# Generate all methods for the stomatal conductance process: several meteo time-steps, components,
#  over an MTG, and the mutating /non-mutating versions
@gen_process_methods gs

"""
    gs(leaf::LeafModels{I,E,A,<:AbstractGsModel,S},gs_mod)
    gs(leaf::LeafModels{I,E,A,<:AbstractGsModel,S},meteo<:AbstractAtmosphere)
    gs!(leaf::LeafModels{I,E,A,<:AbstractGsModel,S},gs_mod)
    gs!(leaf::LeafModels{I,E,A,<:AbstractGsModel,S},meteo<:AbstractAtmosphere)

Default method to compute the stomatal conductance for CO₂ (mol m-2 s-1), it takes the form:

`leaf.stomatal_conductance.g0 + gs_closure(leaf,meteo) * leaf.status.A`

where gs_closure(leaf,meteo) computes the stomatal closure, and must be
implemented for the type of `leaf.stomatal_conductance`. The stomatal conductance is not
allowed to go below `leaf.stomatal_conductance.gs_min`.

# Arguments

- `leaf::LeafModels{I,E,A,<:AbstractGsModel,S}`: A leaf struct holding the parameters for the model. See
[`LeafModels`](@ref), and [`Medlyn`](@ref) or [`ConstantGs`](@ref) for the conductance models.
- `gs_mod`: the output from a [`gs_closure`](@ref) implementation (the conductance models
generally only implement this function)
- `meteo<:AbstractAtmosphere`: meteo data, see [`Atmosphere`](@ref)

# Examples

```julia
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

# Using a constant value for Gs:

leaf = LeafModels(stomatal_conductance = Medlyn(0.03,12.0), # Instance of a Medlyn type
            A = 20.0, Cₛ = 380.0, Dₗ = meteo.VPD)

# Computing the stomatal conductance using the Medlyn et al. (2011) model:
gs(leaf,meteo)
```
"""
gs, gs!

# Gs is used a little bit differently compared to the other processes. We use two forms:
# the stomatal closure and the full computation of Gs
function gs!_(leaf::LeafModels{I,E,A,Gs,S}, gs_closure) where {I,E,A,Gs<:AbstractGsModel,S}
    leaf.status.Gₛ = max(
        leaf.stomatal_conductance.gs_min,
        leaf.stomatal_conductance.g0 + gs_closure * leaf.status.A
    )
end

function gs!_(leaf::LeafModels{I,E,A,Gs,S}, meteo::M, constants = Constants()) where {I,E,A,Gs<:AbstractGsModel,S,M<:Union{AbstractAtmosphere,Nothing}}
    leaf.status.Gₛ = max(
        leaf.stomatal_conductance.gs_min,
        leaf.stomatal_conductance.g0 + gs_closure(leaf, meteo) * leaf.status.A
    )
end
