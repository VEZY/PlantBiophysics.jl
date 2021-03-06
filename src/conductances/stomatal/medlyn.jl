"""
struct to hold the parameters for Medlyn et al. (2011) stomatal
conductance model for CO₂.

# Arguments

- `g0`: intercept.
- `g1`: slope.
- `gs_min = 0.001`: residual conductance. We consider the residual conductance being different
 from `g0` because in practice `g0` can be negative when fitting real-world data.

# Useage

Then used for example as follows:
Gs = Medlyn(0.03,0.1)
gs_mod = gs(Gs,(Cₛ = 400.0, VPD = 1.5))
Gₛ = Gs.g0 + gs_mod * A

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = LeafModels(stomatal_conductance = Medlyn(0.03, 12.0),
            A = A, Cₛ = 380.0, Dₗ = meteo.VPD)
gs(leaf,meteo)
```

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.

"""
struct Medlyn{T} <: AbstractGsModel
    g0::T
    g1::T
    gs_min::T
end

function Medlyn(g0,gs,gs_min)
    Medlyn(promote(g0,gs,gs_min))
end

Medlyn(g0,g1) = Medlyn(g0,g1,oftype(g0,0.001))

Medlyn(;g0,g1) = Medlyn(g0,g1,oftype(g0,0.001))

function inputs(::Medlyn)
    (:Dₗ,:Cₛ,:A)
end

function outputs(::Medlyn)
    (:Gₛ,)
end

Base.eltype(x::Medlyn) = typeof(x).parameters[1]


"""
    gs_closure(leaf::LeafModels{I,E,A,<:Medlyn,S},meteo)

Stomatal closure for CO₂ according to Medlyn et al. (2011). Carefull, this is just a part of
the computation of the stomatal conductance.

The result of this function is then used as:

    gs_mod = gs_closure(leaf,meteo)

    # And then stomatal conductance (μmol m-2 s-1) calling [`gs`](@ref):
    Gₛ = leaf.stomatal_conductance.g0 + gs_mod * leaf.status.A

# Arguments

- `leaf::LeafModels{.,.,<:Fvcb,<:Medlyn,.}`: A [`LeafModels`](@ref) struct holding the parameters for
the model.
- `meteo`: meteorology structure, see [`Atmosphere`](@ref). Is not used in this model.

# Details

Use `variables()` on Medlyn to get the variables that must be instantiated in the `LeafModels` struct.


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

leaf = LeafModels(stomatal_conductance = Medlyn(0.03, 12.0),
            Cₛ = 380.0, Dₗ = meteo.VPD)

gs_mod = gs_closure(leaf, meteo)

A = 20 # example assimilation (μmol m-2 s-1)
Gs = leaf.stomatal_conductance.g0 + gs_mod * A

# Or more directly using `gs()`:

leaf = LeafModels(stomatal_conductance = Medlyn(0.03, 12.0),
            A = A, Cₛ = 380.0, Dₗ = meteo.VPD)
gs(leaf,meteo)
```

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.
"""
function gs_closure(leaf::LeafModels{I,E,A,<:Medlyn,S},meteo) where {I,E,A,S}
    (1.0 + leaf.stomatal_conductance.g1 / sqrt(max(1e-9,leaf.status.Dₗ))) / leaf.status.Cₛ
end
