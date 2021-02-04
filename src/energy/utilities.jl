

"""
    air_density(Tₐ, P)
    air_density(Tₐ, P, Rd, K₀)

ρ, the air density (kg m-3).

# Arguments

- `Tₐ` (Celsius degree): air temperature
- `P` (kPa): air pressure
- `Rd` (J kg-1 K-1): gas constant of dry air (see Foken p. 245, or R bigleaf package).
- `K₀` (Celsius degree): temperature in Celsius degree at 0 Kelvin

# References

Foken, T, 2008: Micrometeorology. Springer, Berlin, Germany.
"""
function air_density(Tₐ, P, Rd, K₀)
    (P * 1000) / (Rd * (Tₐ - K₀))
end

function air_density(Tₐ, P)
    constants = Constants()
    (P * 1000) / (constants.Rd * (Tₐ - constants.K₀))
end

"""
    psychrometric_constant(Tₐ, P, Cₚ, eps)
    psychrometric_constant(Tₐ, P)

γ, the psychrometer constant, also called psychrometric constant (Pa K−1). See Monteith and
Unsworth (2013), p. 222.

# Arguments

- `Tₐ` (Celsius degree): air temperature
- `P` (kPa): air pressure
- `Cₚ` (J kg-1 K-1): specific heat of air at constant pressure (``J\\ K^{-1}\\ kg^{-1}``)
- `ε` (Celsius degree): temperature in Celsius degree at 0 Kelvin

# References

Monteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i)
Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition),
edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.

p 230:
at a standard pressure
of 101.3 kPa, has a value of about 66 Pa K−1 at 0 ◦C increasing to 67 Pa K−1 at 20 ◦C.
"""
function psychrometer_constant(Tₐ, P, Cₚ, ε)
  λ = latent_heat_vaporization(Tₐ)
  gamma = (Cₚ * P)/(ε * λ)
  return gamma
end

"""
    latent_heat_vaporization(Tₐ)

Latent heat of vaporization for water (J kg-1).

# Arguments

- `Tₐ` (Celsius degree): air temperature

# References

Knauer J, El-Madany TS, Zaehle S, Migliavacca M (2018) Bigleaf—An R package for the
calculation of physical and physiological ecosystem properties from eddy covariance data.
PLoS ONE 13(8): e0201114. https://doi.org/10.1371/journal.pone.0201114

Stull, B., 1988: An Introduction to Boundary Layer Meteorology (p.641) Kluwer Academic
Publishers, Dordrecht, Netherlands

Foken, T, 2008: Micrometeorology. Springer, Berlin, Germany.
"""
function latent_heat_vaporization(Tₐ)
  (2.501 - 0.00237 * Tₐ) * 1.0e6
end
