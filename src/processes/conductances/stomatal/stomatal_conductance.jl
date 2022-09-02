"""
Stomatal conductance abstract model. All stomatal conductance models must be a subtype of
this type.

An AbstractGsModel subtype struct must implement at least a g0 field.
"""
abstract type AbstractGsModel <: AbstractModel end

# Generate all methods for the stomatal conductance process: several meteo time-steps, components,
#  over an MTG, and the mutating /non-mutating versions
@gen_process_methods "stomatal_conductance"

"""
    stomatal_conductance(leaf::ModelList,gs_mod)
    stomatal_conductance(leaf::ModelList,meteo<:AbstractAtmosphere)

Default method to compute the stomatal conductance for CO₂ (mol m-2 s-1), it takes the form:

`leaf.stomatal_conductance.g0 + gs_closure(leaf,meteo) * leaf.status.A`

where gs_closure(leaf,meteo) computes the stomatal closure, and must be
implemented for the type of `leaf.stomatal_conductance`. The stomatal conductance is not
allowed to go below `leaf.stomatal_conductance.gs_min`.

# Arguments

- `Gs::Gsm`: a stomatal conductance model, usually the leaf model (*i.e.* leaf.stomatal_conductance)
- `models::ModelList`: A leaf struct holding the parameters for the model. See
[`ModelList`](@ref), and [`Medlyn`](@ref) or [`ConstantGs`](@ref) for the conductance models.
- `status::Status`: A status, usually the leaf status (*i.e.* leaf.status)
- `gs_mod`: the output from a [`gs_closure`](@ref) implementation (the conductance models
generally only implement this function)
- `meteo<:AbstractAtmosphere`: meteo data, see [`Atmosphere`](@ref)

# Examples

```julia
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

# Using a constant value for Gs:

leaf =
    ModelList(
        stomatal_conductance = Medlyn(0.03,12.0), # Instance of a Medlyn type
        status = (A = 20.0, Cₛ = 380.0, Dₗ = meteo.VPD)
    )

# Computing the stomatal conductance using the Medlyn et al. (2011) model:
stomatal_conductance(leaf,meteo)
```
"""
stomatal_conductance, stomatal_conductance!

# Gs is used a little bit differently compared to the other processes. We use two forms:
# the stomatal closure and the full computation of Gs
function stomatal_conductance!_(Gs::Gsm, models, status, gs_closure) where {Gsm<:AbstractGsModel}
    status.Gₛ = max(
        models.stomatal_conductance.gs_min,
        models.stomatal_conductance.g0 + gs_closure * status.A
    )
end

function stomatal_conductance!_(Gs::Gsm, models, status, meteo::M, constants=Constants()) where {Gsm<:AbstractGsModel,M<:Union{AbstractAtmosphere,Nothing}}
    status.Gₛ = max(
        models.stomatal_conductance.gs_min,
        models.stomatal_conductance.g0 + gs_closure(models.stomatal_conductance, models, status, meteo) * status.A
    )
end
