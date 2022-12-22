"""
γ_star(γ, a_sh, a_s, rbv, Rsᵥ, Rbₕ)

γ∗, the apparent value of psychrometer constant (kPa K−1).

# Arguments

- `γ` (kPa K−1): psychrometer constant
- `aₛₕ` (1,2): number of faces exchanging heat fluxes (see Schymanski et al., 2017)
- `aₛᵥ` (1,2): number of faces exchanging water fluxes (see Schymanski et al., 2017)
- `Rbᵥ` (s m-1): boundary layer resistance to water vapor
- `Rsᵥ` (s m-1): stomatal resistance to water vapor
- `Rbₕ` (s m-1): boundary layer resistance to heat

# Note

Using the corrigendum from Schymanski et al. (2017) in here so the definition of
[`latent_heat`](@ref) remains generic.

Not to be confused with [`Γ_star`](@ref) the CO₂ compensation point.

# References

Monteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i)
Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition),
edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.

Schymanski, Stanislaus J., et Dani Or. 2017. Leaf-Scale Experiments Reveal an Important
Omission in the Penman–Monteith Equation ». Hydrology and Earth System Sciences 21 (2): 685‑706.
https://doi.org/10.5194/hess-21-685-2017.
"""
function γ_star(γ, aₛₕ, aₛᵥ, Rbᵥ, Rsᵥ, Rbₕ)
    γ * aₛₕ / aₛᵥ * (Rbᵥ + Rsᵥ) / Rbₕ # rv + Rsᵥ= Boundary + stomatal conductance to water vapour
end
