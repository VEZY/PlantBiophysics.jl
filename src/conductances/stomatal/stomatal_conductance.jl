"""
    gs(leaf::Leaf{I,E,A,<:AbstractGsModel,S},gs_mod)
    gs(leaf::Leaf{I,E,A,<:AbstractGsModel,S},meteo<:Atmosphere)
    gs!(leaf::Leaf{I,E,A,<:AbstractGsModel,S},gs_mod)
    gs!(leaf::Leaf{I,E,A,<:AbstractGsModel,S},meteo<:Atmosphere)

Default method to compute the stomatal conductance for CO₂ (mol m-2 s-1), it takes the form:

`leaf.stomatal_conductance.g0 + gs_closure(leaf,meteo) * leaf.status.A`

where gs_closure(leaf,meteo) computes the stomatal closure, and must be
implemented for the type of `leaf.stomatal_conductance`.

# Arguments

- `leaf::Leaf{I,E,A,<:AbstractGsModel,S}`: A leaf struct holding the parameters for the model. See
[`Leaf`](@ref), and [`Medlyn`](@ref) or [`ConstantGs`](@ref) for the conductance models.
- `gs_mod`: the output from a [`gs_closure`](@ref) implementation (the conductance models
generally only implement this function)
- `meteo<:Atmosphere`: meteo data, see [`Atmosphere`](@ref)

# Examples

```julia
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

# Using a constant value for Gs:

leaf = Leaf(stomatal_conductance = Medlyn(0.03,12.0), # Instance of a Medlyn type
            A = 20.0, Cₛ = 380.0, Dₗ = meteo.VPD)

# Computing the stomatal conductance using the Medlyn et al. (2011) model:
gs(leaf,meteo)
```
"""
function gs(leaf::Leaf{I,E,A,Gs,S},gs_mod) where {I,E,A,Gs<:AbstractGsModel,S}
    leaf.stomatal_conductance.g0 + gs_mod * leaf.status.A
end

function gs(leaf::Leaf{I,E,A,Gs,S},meteo::M) where {I,E,A,Gs<:AbstractGsModel,S,M<:Atmosphere}
    leaf.stomatal_conductance.g0 + gs_closure(leaf,meteo) * leaf.status.A
end

function gs!(leaf::Leaf{I,E,A,Gs,S},gs_mod) where {I,E,A,Gs<:AbstractGsModel,S}
    leaf.status.Gₛ = leaf.stomatal_conductance.g0 + gs_mod * leaf.status.A
end

function gs!(leaf::Leaf{I,E,A,Gs,S},meteo::M) where {I,E,A,Gs<:AbstractGsModel,S,M<:Atmosphere}
    leaf.status.Gₛ = leaf.stomatal_conductance.g0 + gs_closure(leaf,meteo) * leaf.status.A
end
