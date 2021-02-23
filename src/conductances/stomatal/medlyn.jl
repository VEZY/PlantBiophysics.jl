"""
struct to hold the parameters for Medlyn et al. (2011) stomatal
conductance model for CO₂ .

Then used for example as follows:
Gs = Medlyn(0.03,0.1)
gs_mod = gs(Gs,(Cₛ = 400.0, VPD = 1.5))
Gₛ = Gs.g0 + gs_mod * A

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.

"""
Base.@kwdef struct Medlyn{T} <: AbstractGsModel
 g0::T
 g1::T
end

function variables(::Medlyn)
    (:Dₗ,:Cₛ,:A,:Gₛ)
end

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
    (1.0 + leaf.stomatal_conductance.g1 / sqrt(leaf.status.Dₗ)) / leaf.status.Cₛ
end
