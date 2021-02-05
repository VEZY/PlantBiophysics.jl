# Implement the generic gs function. Then dispatch the method on the Gs argument.

"""
Stomatal conductance for CO₂ (mol m-2 s-1).

# Arguments

- `Gs::GsModel`: The struct holding the parameters for the model. See
[`Medlyn`](@ref) or [`ConstantGs`](@ref).
- A (μmol m-2 s-1): the C assimilation
- Cₛ (ppm): the stomatal CO₂ concentration
- VPD (kPa): the air - leaf vapor pressure deficit
- Rh (0-1): the relative humidity of the air
- ψₗ (kPa): the leaf water potential

# Note

The stomatal conductance model used is defined by the type of the `Gs` argument. Then
the user is expected to provide the optional parameters needed for that model, *e.g.*
for Gs::Medlyn, `gs()` needs the VPD (see [`gs_closure`](@ref)).

# Examples

```julia
A = 20 # assimilation (umol m-2 s-1)
Cₛ = 400.0 # Stomatal CO₂ concentration (ppm)
Gs = Medlyn(0.03,0.1) # Instance of a Medlyn type with g0 = 0.03 and g1 = 0.1

# Computing the stomatal conductance using the Medlyn et al. (2011) model:
gs(Gs,A,Cₛ,VPD = 2.0)

# Note that VPD is a keyword argument, so it must be named explicitely.
```

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.
```
"""
function gs(Gs::GsModel,A,Cₛ;VPD = missing,Rh = missing,ψₗ = missing)
    Gs.g0 + gs_closure(Gs,(VPD = VPD, Cₛ = Cₛ, Rh = Rh, ψₗ = ψₗ)) * A
end
