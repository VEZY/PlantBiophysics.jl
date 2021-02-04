

"""
    air_density(Tₐ, P)
    air_density(Tₐ, P, Rd, K₀)

ρ, the air density (kg m-3).

# Arguments

- `Tₐ` (Celsius degree): air temperature
- `P` (kPa): air pressure
- `Rd` (J kg-1 K-1): gas constant of dry air (see Foken p. 245, or R bigleaf package).
- `K₀` (Celsius degree): temperature in Celsius degree at 0 Kelvin

# Note

Rd and K₀ are Taken from [`Constants`](@ref) if not provided.

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
    psychrometer_constant(Tₐ, P, Cₚ, ε)
    psychrometer_constant(Tₐ, P)

γ, the psychrometer constant, also called psychrometric constant (kPa K−1). See Monteith and
Unsworth (2013), p. 222.

# Arguments

- `Tₐ` (Celsius degree): air temperature
- `P` (kPa): air pressure
- `Cₚ` (J kg-1 K-1): specific heat of air at constant pressure (``J\\ K^{-1}\\ kg^{-1}``)
- `ε` (Celsius degree): temperature in Celsius degree at 0 Kelvin
- `λ₀`: latent heat of vaporization for water at 0 degree Celsius (``J\\ kg^{-1}``).

# Note

Cₚ, ε and λ₀ are taken from [`Constants`](@ref) if not provided.

# References

Monteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i)
Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition),
edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.

"""
function psychrometer_constant(Tₐ, P, Cₚ, ε, λ₀)
    λ = latent_heat_vaporization(Tₐ, λ₀)
    γ = (Cₚ * P)/(ε * λ)
    return γ
end

function psychrometer_constant(Tₐ, P)
    constant = Constants()
    λ = latent_heat_vaporization(Tₐ, constant.λ₀)
    γ = (constant.Cₚ * P)/(constant.ε * λ)
    return γ
end

"""
    latent_heat_vaporization(Tₐ,λ₀)
    latent_heat_vaporization(Tₐ)

λ, the latent heat of vaporization for water (J kg-1).

# Arguments

- `Tₐ` (Celsius degree): air temperature
- `λ₀`: latent heat of vaporization for water at 0 degree Celsius. Taken from Constants().λ₀
if not provided.

"""
function latent_heat_vaporization(Tₐ,λ₀)
  λ₀ - 2.365e3 * Tₐ
end

function latent_heat_vaporization(Tₐ)
  Constants().λ₀ - 2.365e3 * Tₐ
end
