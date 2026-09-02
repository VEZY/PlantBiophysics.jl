# Generate all methods for the stomatal conductance process: several environment time-steps, components,
#  over an MTG, and the mutating /non-mutating versions
@process "stomatal_conductance" """
Process for the stomatal conductance for CO₂ (μmol m⁻² s⁻¹), it takes the form:

`leaf.stomatal_conductance.g0 + gs_closure(leaf,environment) * leaf.status.A`

where gs_closure(leaf,environment) computes the stomatal closure, and must be
implemented for the type of `leaf.stomatal_conductance`. The stomatal conductance is not
allowed to go below `leaf.stomatal_conductance.gs_min`.

# Arguments

- `Gs::Gsm`: a stomatal conductance model, usually the leaf model (*i.e.* leaf.stomatal_conductance)
- `status::Status`: A status, usually the leaf status (*i.e.* leaf.status)
- `gs_mod`: the output from a `gs_closure` implementation (the conductance models
generally only implement this function)
- `environment<:PlantMeteo.AbstractAtmosphere`: environment data, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)

# Examples

```julia
using PlantMeteo, PlantSimEngine, PlantBiophysics
environment = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

# Using a constant value for Gs:

scene = leaf_scene(
    Medlyn(0.03,12.0);
    status=Status(A=20.0, Cₛ=380.0, Dₗ=environment.VPD),
    environment=environment,
)
run!(scene)
only(model_objects(scene; scale=:Leaf)).status.Gₛ
```
""" verbose = false

# Default policy for stomatal conductance when consumed at coarser clocks.
# Conductance is typically summarized over a window rather than accumulated.
PlantSimEngine.output_policy(::Type{<:AbstractStomatal_ConductanceModel}) = (Gₛ=PlantSimEngine.Aggregate(PlantMeteo.DurationSumReducer()),)

# A parent photosynthesis model can pass a precomputed closure value through
# sampled_environment; ordinary scheduled execution receives a sampled environment row.
function PlantSimEngine.run!(Gs::Gsm, status, environment, constants, context) where {Gsm<:AbstractStomatal_ConductanceModel}
    closure = environment isa Number ?
              environment :
              gs_closure(Gs, status, environment, constants, context)
    status.Gₛ = max(
        Gs.gs_min,
        Gs.g0 + closure * status.A,
    )
end
