# Generate all methods for the stomatal conductance process: several meteo time-steps, components,
#  over an MTG, and the mutating /non-mutating versions
@process "stomatal_conductance" """
Process for the stomatal conductance for CO₂ (mol m⁻² s⁻¹), it takes the form:

`leaf.stomatal_conductance.g0 + gs_closure(leaf,meteo) * leaf.status.A`

where gs_closure(leaf,meteo) computes the stomatal closure, and must be
implemented for the type of `leaf.stomatal_conductance`. The stomatal conductance is not
allowed to go below `leaf.stomatal_conductance.gs_min`.

# Arguments

- `Gs::Gsm`: a stomatal conductance model, usually the leaf model (*i.e.* leaf.stomatal_conductance)
- `models::ModelList`: A leaf struct holding the parameters for the model. See
`ModelList`, and `Medlyn` or `ConstantGs` for the conductance models.
- `status::Status`: A status, usually the leaf status (*i.e.* leaf.status)
- `gs_mod`: the output from a `gs_closure` implementation (the conductance models
generally only implement this function)
- `meteo<:PlantMeteo.AbstractAtmosphere`: meteo data, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)

# Examples

```julia
using PlantMeteo, PlantSimEngine, PlantBiophysics
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

# Using a constant value for Gs:

leaf =
    ModelList(
        stomatal_conductance = Medlyn(0.03,12.0), # Instance of a Medlyn type
        status = (A = 20.0, Cₛ = 380.0, Dₗ = meteo.VPD)
    )

# Computing the stomatal conductance using the Medlyn et al. (2011) model:
run!(leaf,meteo)
```
""" verbose = false

# Gs is used a little bit differently compared to the other processes. We use two forms:
# the stomatal closure and the full computation of Gs
function PlantSimEngine.run!(Gs::Gsm, models, status, gs_closure, extra) where {Gsm<:AbstractStomatal_ConductanceModel}
    status.Gₛ = max(
        models.stomatal_conductance.gs_min,
        models.stomatal_conductance.g0 + gs_closure * status.A
    )
end

function PlantSimEngine.run!(Gs::Gsm, models, status, meteo, constants, extra) where {Gsm<:AbstractStomatal_ConductanceModel}
    status.Gₛ = max(
        models.stomatal_conductance.gs_min,
        models.stomatal_conductance.g0 + gs_closure(models.stomatal_conductance, models, status, meteo, constants, extra) * status.A
    )
end
