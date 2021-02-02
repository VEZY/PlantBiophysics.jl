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
Stomatal closure for CO₂ according to Medlyn et al. (2011). Carefull, this is just a part of
the computation of the stomatal conductance.

The result of this function is then used as:

    gs_mod = gs_closure(Gs,gs_vars)

    # And then stomatal conductance (μmol m-2 s-1):
    Gₛ = Gs.g0 + gs_mod * A

# Arguments

- `Gs::Medlyn`: The struct holding the parameters for the model (g0 and g1)
- `gs_vars::NamedTuple{(:Cₛ, :VPD),NTuple{4,Float64}}`: the values of the variables:
    - Cₛ (ppm): the stomatal CO₂ concentration
    - VPD (kPa): the vapor pressure deficit of the air

# Examples

```julia
A = 20 # assimilation (umol m-2 s-1)
Gs = Medlyn(0.03,0.1)
gs_mod = gs_closure(Gs, (Cₛ = 400.0, VPD = 1.5))
gs = Gs.g0 + gs_mod * A
```

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.
"""
function gs_closure(Gs::Medlyn,gs_vars)
    (1.0 + Gs.g1 / sqrt(gs_vars.VPD)) / gs_vars.Cₛ
end
