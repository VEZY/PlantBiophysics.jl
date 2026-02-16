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
    ModelList(
        stomatal_conductance = Medlyn(0.03, 12.0),
        status = (A = A, Cₛ = 380.0, Dₗ = meteo.VPD)
    )
run!(leaf,meteo)
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

Base.eltype(::Medlyn{T}) where T = T

"""
    gs_closure(::Medlyn, models, status, meteo, constants=nothing, extra=nothing)

Stomatal closure for CO₂ according to Medlyn et al. (2011). Carefull, this is just a part of
the computation of the stomatal conductance.

The result of this function is then used as:

    gs_mod = gs_closure(leaf,meteo)

    # And then stomatal conductance (μmol m-2 s-1) calling [`stomatal_conductance`](@ref):
    Gₛ = leaf.stomatal_conductance.g0 + gs_mod * leaf.status.A

# Arguments

- `::Medlyn`: an instance of the `Medlyn` model type
- `models::ModelList`: A `ModelList` struct holding the parameters for the models.
- `status`: A status struct holding the variables for the models.
- `meteo`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere). Is not used in this model.
- `constants`: A constants struct holding the constants for the models. Is not used in this model.
- `extra`: A struct holding the extra variables for the models. Is not used in this model.

# Details

Use `variables()` on Medlyn to get the variables that must be instantiated in the
`ModelList` struct.

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

leaf =
    ModelList(
        stomatal_conductance = Medlyn(0.03, 12.0),
        status = (Cₛ = 380.0, Dₗ = meteo.VPD)
    )

gs_mod = gs_closure(leaf, meteo)

A = 20 # example assimilation (μmol m-2 s-1)
Gs = leaf.stomatal_conductance.g0 + gs_mod * A

# Or more directly using `run!()`:

leaf =
    ModelList(
        stomatal_conductance = Medlyn(0.03, 12.0),
        status = (A = A, Cₛ = 380.0, Dₗ = meteo.VPD)
    )
run!(leaf,meteo)
```

Note that we use `VPD` as an approximation of `Dₗ` here because we don't have the leaf temperature (*i.e.* `Dₗ = VPD` when `Tₗ = T`).

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.
"""
function gs_closure(::Medlyn, models, status, meteo, constants=nothing, extra=nothing)
    (1.0 + models.stomatal_conductance.g1 / sqrt(max(1e-9, status.Dₗ))) / status.Cₛ
end

PlantSimEngine.ObjectDependencyTrait(::Type{<:Medlyn}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:Medlyn}) = PlantSimEngine.IsTimeStepIndependent()
PlantSimEngine.timestep_hint(::Type{<:Medlyn}) = (
    required=(Dates.Minute(1), Dates.Hour(6)),
    preferred=Dates.Hour(1)
)
