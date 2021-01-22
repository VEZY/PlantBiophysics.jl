

"""
struct to hold the parameters for Medlyn et al. (2011) stomatal
conductance model for CO₂ .

Then used as follows:
Gs = ConstantGs(0.03,0.1)
gs_mod = gs(Gs,VPD,Cₛ)
Gₛ = Gs.g0 + gs_mod * A

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.

"""
struct Medlyn{T} <: GsModel
 g0::T
 g1::T
end

"""
Stomatal closure for CO₂ according to Medlyn et al. (2011).
The result of this function is then used as:

    gs_mod = gs(Gs,VPD,Cₛ) # Gs = Medlyn(0.03,0.1)

    # Stomatal conductance (μmol m-2 s-1):
    Gₛ = g0 + gs_mod * A

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.
"""
function gs(Gs::Medlyn,VPD,Cₛ)
    (1.0 + Gs.g1 / sqrt(VPD)) / Cₛ
end
