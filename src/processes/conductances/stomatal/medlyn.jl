"""
Medlyn et al. (2011) stomatal conductance model for CO₂.

# Arguments

- `g0`: intercept, it is the minimal stomatal conductance.
- `g1`: slope.
- `gs_min = 0.001`: residual conductance. We consider the residual conductance being different
    from `g0` because in practice `g0` can be negative when fitting real-world data.

# Examples

```julia
using PlantMeteo, PlantSimEngine, PlantBiophysics
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf =
    leaf_scene(
        Medlyn(0.03, 12.0);
        status=Status(A=20.0, Cₛ=380.0, Dₗ=meteo.VPD),
        environment=meteo,
    )
run!(leaf)
```

Note that we use `VPD` as an approximation of `Dₗ` here because we don't have the leaf temperature (*i.e.* `Dₗ = VPD` when `Tₗ = T`).

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.
"""
struct Medlyn{T} <: AbstractStomatal_ConductanceModel
    g0::T
    g1::T
    gs_min::T
end

function Medlyn(g0, g1, gs_min=oftype(g0, 0.001))
    Medlyn(promote(g0, g1, gs_min))
end

Medlyn(; g0, g1, gs_min=0.001) = Medlyn(g0, g1, gs_min)

function PlantSimEngine.inputs_(::Medlyn)
    (Dₗ=-Inf, Cₛ=-Inf, A=-Inf)
end

function PlantSimEngine.outputs_(::Medlyn)
    (Gₛ=-Inf,)
end

PlantSimEngine.output_policy(::Type{<:Medlyn}) = (
    Gₛ=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()),
)

Base.eltype(::Medlyn{T}) where T = T

"""
    gs_closure(model::Medlyn, status, environment, constants=nothing, context=nothing)

Stomatal closure for CO₂ according to Medlyn et al. (2011). Carefull, this is just a part of
the computation of the stomatal conductance.

The result of this function is then used as:

    gs_mod = gs_closure(leaf,meteo)

    # And then stomatal conductance (μmol m-2 s-1) calling [`stomatal_conductance`](@ref):
    Gₛ = leaf.stomatal_conductance.g0 + gs_mod * leaf.status.A

# Arguments

- `::Medlyn`: an instance of the `Medlyn` model type
- `status`: A status struct holding the variables for the models.
- `environment`: sampled environment, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere). Is not used in this model.
- `constants`: A constants struct holding the constants for the models. Is not used in this model.
- `context`: PlantSimEngine runtime context. It is not used in this model.

# Details

Use `variables(Medlyn(...))` to inspect the model contract. Variables not
provided by another application must be initialized in the target `Status`.

# Notes

- `Cₛ` is used instead of `Cₐ` because Gₛ is between the surface and the intercellular space. The conductance
between the atmosphere and the surface is accounted for using the boundary layer conductance
(`Gbc` in [`Monteith`](@ref)). Medlyn et al. (2011) uses `Cₐ` in their paper because they relate their models
to the measurements made at leaf level, with a well-mixed chamber where`Cₛ ≈ Cₐ`.
- `Dₗ` is forced to be >= 1e-9 because it is used in a squared root. It is prefectly acceptable to
get a negative Dₗ when leaves are re-hydrating from air. Cloud forests are the perfect example.
See *e.g.*: Guzmán‐Delgado, P, Laca, E, Zwieniecki, MA. Unravelling foliar water uptake pathways:
The contribution of stomata and the cuticle. Plant Cell Environ. 2021; 1– 13.
https://doi.org/10.1111/pce.14041

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

A = 20 # example assimilation (μmol m-2 s-1)
scene = leaf_scene(
    Medlyn(0.03, 12.0);
    status=Status(A=A, Cₛ=380.0, Dₗ=meteo.VPD),
    environment=meteo,
)
run!(scene)
only(model_objects(scene; scale=:Leaf)).status.Gₛ
```

Note that we use `VPD` as an approximation of `Dₗ` here because we don't have the leaf temperature (*i.e.* `Dₗ = VPD` when `Tₗ = T`).

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.
"""
function gs_closure(model::Medlyn, status, environment, constants=nothing, context=nothing)
    (1.0 + model.g1 / sqrt(max(1e-9, status.Dₗ))) / status.Cₛ
end

PlantSimEngine.timestep_hint(::Type{<:Medlyn}) = (
    required=(Dates.Minute(1), Dates.Hour(6)),
    preferred=Dates.Hour(1)
)
