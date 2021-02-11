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
Base.@kwdef struct Medlyn{T} <: GsModel
 g0::T
 g1::T
end

"""
    gs_closure(leaf::Leaf{G,I,E,A,<:Medlyn,S},meteo)

Stomatal closure for CO₂ according to Medlyn et al. (2011). Carefull, this is just a part of
the computation of the stomatal conductance.

The result of this function is then used as:

    gs_mod = gs_closure(Gs,gs_vars)

    # And then stomatal conductance (μmol m-2 s-1):
    Gₛ = Gs.g0 + gs_mod * A

# Arguments

- `leaf::Leaf{.,.,.,<:Fvcb,<:GsModel,.}`: A [`Leaf`](@ref) struct holding the parameters for
the model
- `meteo`: meteorology structure, see [`Atmosphere`](@ref). Is used to hold the values for
the VPD (kPa, the vapor pressure deficit of the air) here.

# Examples

```julia
using MutableNamedTuples

meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = Leaf(photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            status = MutableNamedTuple(Cₛ = 400.0))


gs_mod = PlantBiophysics.gs_closure(leaf, meteo)

A = 20 # example assimilation (μmol m-2 s-1)
gs = leaf.stomatal_conductance.g0 + gs_mod * A
```

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.
"""
function gs_closure(leaf::Leaf{G,I,E,A,<:Medlyn,S},meteo) where {G,I,E,A,S}
    (1.0 + leaf.stomatal_conductance.g1 / sqrt(meteo.VPD)) / leaf.status.Cₛ
end

function gs(leaf::Leaf{G,I,E,A,<:Medlyn,S},gs_mod) where {G,I,E,A,S}
    leaf.stomatal_conductance.g0 + gs_mod * leaf.status.A
end

function gs(leaf::Leaf{G,I,E,A,<:Medlyn,S},meteo::M) where {G,I,E,A,S,M<:Atmosphere}
    leaf.stomatal_conductance.g0 + gs_closure * leaf.status.A
end
