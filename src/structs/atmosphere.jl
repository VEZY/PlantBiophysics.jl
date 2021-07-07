"""
Atmosphere structure to hold all values related to the meteorology / atmoshpere.

# Arguments

- `T` (°C): air temperature
- `Wind` (m s-1): wind speed
- `P` (kPa): air pressure
- `Rh = rh_from_vpd(VPD,eₛ)` (0-1): relative humidity
- `Cₐ` (ppm): air CO₂ concentration
- `e = vapor_pressure(T,Rh)` (kPa): vapor pressure
- `eₛ = e_sat(T)` (kPa): saturated vapor pressure
- `VPD = eₛ - e` (kPa): vapor pressure deficit
- `ρ = air_density(T, P, constants.Rd, constants.K₀)` (kg m-3): air density
- `λ = latent_heat_vaporization(T, constants.λ₀)` (J kg-1): latent heat of vaporization
- `γ = psychrometer_constant(P, λ, constants.Cₚ, constants.ε)` (kPa K−1): psychrometer "constant"
- `ε = atmosphere_emissivity(T,e,constants.K₀)` (0-1): atmosphere emissivity
- `Δ = e_sat_slope(meteo.T)` (0-1): slope of the saturation vapor pressure at air temperature

# Notes

The structure can be built using only `T`, `Rh`, `Wind` and `P`. All other variables are oprional
and can be automatically computed using the functions given in `Arguments`.

# Examples

```julia
Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
```
"""
Base.@kwdef struct Atmosphere{A}
    T::A
    Wind::A
    P::A
    Rh::A
    Cₐ::A = 400.0
    e::A = vapor_pressure(T,Rh)
    eₛ::A = e_sat(T)
    VPD::A = eₛ - e
    ρ::A = air_density(T, P) # in kg m-3
    λ::A = latent_heat_vaporization(T)
    γ::A = psychrometer_constant(P, λ) # in kPa K−1
    ε::A = atmosphere_emissivity(T,e)
    Δ::A = e_sat_slope(T)
end

"""

```julia
w = Weather(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ],
    "Test site"
    )
```
"""
struct Weather{D <: AbstractArray,S <: AbstractString}
    data::D
    site::S
end


function Weather(df::DataFrame)
    @assert findfirst(x -> x == "site", names(df)) "The input `DataFrame` should have a column called site"
    Weather(df[!, DataFrames.Not(:site)],unique(df.site))
end

function Base.show(io::IO, n::Weather)
    print(io,"Wheather data from `$(n.site)`:\n")
    print(DataFrame(n))
    return nothing
end

"""
    DataFrame(data::Weather)

Transform a Weather type into a DataFrame.

See also [`Weather`](@Ref) to make the reverse.
"""
function DataFrame(data::Weather)
    df = DataFrame(data.data)
    # df.site .= data.site
    df[!,:site] .= data.site
    return df
end

"""
    vapor_pressure(Tₐ, rh)
Vapor pressure (kPa) at given temperature (°C) and relative hunidity (0-1).
"""
function vapor_pressure(Tₐ, rh)
    rh * e_sat(Tₐ)
end


"""
    e_sat(T)

Saturated water vapour pressure (es, in kPa) at given temperature `T` (°C).
See Jones (1992) p. 110 for the equation.
"""
function e_sat(T)
  0.61375 * exp((17.502 * T) / (T + 240.97))
end

"""
    e_sat_slope(T)

Slope of the vapor pressure saturation curve at a given temperature `T` (°C).
"""
function e_sat_slope(T)
  (e_sat(T + 0.1) - e_sat(T)) / 0.1
end


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
    air_density(Tₐ, P, constants.Rd, constants.K₀)
end

"""
    psychrometer_constant(P, λ, Cₚ, ε)
    psychrometer_constant(P, λ)

γ, the psychrometer constant, also called psychrometric constant (kPa K−1). See Monteith and
Unsworth (2013), p. 222.

# Arguments

- `P` (kPa): air pressure
- `λ` (``J\\ kg^{-1}``): latent heat of vaporization for water (see [`latent_heat_vaporization`](@ref))
- `Cₚ` (J kg-1 K-1): specific heat of air at constant pressure (``J\\ K^{-1}\\ kg^{-1}``)
- `ε` (Celsius degree): temperature in Celsius degree at 0 Kelvin

# Note

Cₚ, ε and λ₀ are taken from [`Constants`](@ref) if not provided.


```julia
Tₐ = 20.0

λ = latent_heat_vaporization(Tₐ, λ₀)
psychrometer_constant(100.0, λ)
```

# References

Monteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i)
Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition),
edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.

"""
function psychrometer_constant(P, λ, Cₚ, ε)
    γ = (Cₚ * P)/(ε * λ)
    return γ
end

function psychrometer_constant(P, λ)
    constant = Constants()
    γ = (constant.Cₚ * P) / (constant.ε * λ)
    return γ
end

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

Not to be confused with [`Γ_star`](@ref) in FcVB model, which is the CO₂ compensation point.

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


"""
    latent_heat_vaporization(Tₐ,λ₀)
    latent_heat_vaporization(Tₐ)

λ, the latent heat of vaporization for water (J kg-1).

# Arguments

- `Tₐ` (°C): air temperature
- `λ₀`: latent heat of vaporization for water at 0 degree Celsius. Taken from `Constants().λ₀`
if not provided (see [`Constants`](@ref)).

"""
function latent_heat_vaporization(Tₐ,λ₀)
  λ₀ - 2.365e3 * Tₐ
end

function latent_heat_vaporization(Tₐ)
    latent_heat_vaporization(Tₐ,Constants().λ₀)
end
