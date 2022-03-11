"""
Physical constants

The definition and default values are:

- `K₀ = -273.15`: absolute zero (°C)
- `R = 8.314`: universal gas constant (``J\\ mol^{-1}\\ K^{-1}``).
- `Rd = 287.0586`: gas constant of dry air (``J\\ kg^{-1}\\ K^{-1}``).
- `Dₕ₀ = 21.5e-6`: molecular diffusivity for heat at base temperature, applied in the integrated form of the
    Fick’s Law of diffusion (``m^2\\ s^{-1}``). See eq. 3.10 from Monteith and Unsworth (2013).
- `Cₚ = 1013.0`: Specific heat of air at constant pressure (``J\\ K^{-1}\\ kg^{-1}``), also
    known as efficiency of impaction of particles. See Allen et al. (1998), or Monteith and
    Unsworth (2013). NB: bigleaf R package uses 1004.834 intead.
- `ε = 0.622`: ratio of molecular weights of water vapor and air. See Monteith and
    Unsworth (2013).
- `λ₀ = 2.501`: latent heat of vaporization for water at 0 degree (``J\\ kg^{-1}``).
- `σ = 5.670373e-08` [Stefan-Boltzmann constant](https://en.wikipedia.org/wiki/Stefan%E2%80%93Boltzmann_law)
    in (``W\\ m^{-2}\\ K^{-4}``).
- `Gbₕ_to_Gbₕ₂ₒ = 1.075`: conversion coefficient from conductance to heat to conductance to water
    vapor.
- `Gsc_to_Gsw = 1.57`: conversion coefficient from stomatal conductance to CO₂ to conductance to water
    vapor.
- `Gbc_to_Gbₕ = 1.32`: conversion coefficient from boundary layer conductance to CO₂ to heat.
- `Mₕ₂ₒ = 18.0e-3` (kg mol-1): Molar mass for water.

# References

Allen, Richard G., Luis S. Pereira, Dirk Raes, et Martin J Fao Smith. 1998.
« Crop evapotranspiration-Guidelines for computing crop water requirements-FAO Irrigation
and drainage paper 56 » 300 (9): D05109.

Monteith, John, et Mike Unsworth. 2013. Principles of environmental physics: plants,
animals, and the atmosphere. Academic Press.
"""
Base.@kwdef struct Constants{T}
    K₀::T = -273.15
    R::T = 8.314
    Rd::T = 287.0586
    Dₕ₀::T = 21.2e-6
    Cₚ::T = 1013.0
    ε::T = 0.622
    λ₀::T = 2.501e6
    σ::T = 5.670373e-08
    Gbₕ_to_Gbₕ₂ₒ::T = 1.075
    Gsc_to_Gsw::T = 1.57
    Gbc_to_Gbₕ::T = 1.32
    Mₕ₂ₒ::T = 18.0e-3
    J_to_umol::T = 4.57
end
