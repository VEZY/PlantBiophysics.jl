"""
Abstract atmospheric conditions type. The suptypes of AbstractAtmosphere should describe the
atmospheric conditions for one time-step only, see *e.g.* [`Atmosphere`](@ref)
"""
abstract type AbstractAtmosphere end


"""
Atmosphere structure to hold all values related to the meteorology / atmosphere.

# Arguments

- `date = Dates.now()`: the date of the record.
- `duration = 1.0` (seconds): the duration of the time-step.
- `T` (°C): air temperature
- `Wind` (m s-1): wind speed
- `P = 101.325` (kPa): air pressure. The default value is at 1 atm, *i.e.* the mean sea-level
atmospheric pressure on Earth.
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
- `clearness::A = 9999.9` (0-1): Sky clearness
- `Ri_SW_f::A = 9999.9` (W m-2): Incoming short wave radiation flux
- `Ri_PAR_f::A = 9999.9` (W m-2): Incoming PAR radiation flux
- `Ri_NIR_f::A = 9999.9` (W m-2): Incoming NIR radiation flux
- `Ri_TIR_f::A = 9999.9` (W m-2): Incoming TIR radiation flux
- `Ri_custom_f::A = 9999.9` (W m-2): Incoming radiation flux for a custom waveband

# Notes

The structure can be built using only `T`, `Rh`, `Wind` and `P`. All other variables are optional
and can be automatically computed using the functions given in `Arguments`.

# Examples

```julia
Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
```
"""
struct Atmosphere{A,D1,D2} <: AbstractAtmosphere
    date::D1
    duration::D2
    T::A
    Wind::A
    P::A
    Rh::A
    Cₐ::A
    e::A
    eₛ::A
    VPD::A
    ρ::A
    λ::A
    γ::A
    ε::A
    Δ::A
    clearness::A
    Ri_SW_f::A
    Ri_PAR_f::A
    Ri_NIR_f::A
    Ri_TIR_f::A
    Ri_custom_f::A
end

function Atmosphere(;
    date = Dates.now(), duration = 1.0, T, Wind, P = 101.325, Rh,
    Cₐ = 400.0, e = vapor_pressure(T, Rh), eₛ = e_sat(T), VPD = eₛ - e,
    ρ = air_density(T, P), λ = latent_heat_vaporization(T),
    γ = psychrometer_constant(P, λ), ε = atmosphere_emissivity(T, e),
    Δ = e_sat_slope(T), clearness = 9999.9, Ri_SW_f = 9999.9, Ri_PAR_f = 9999.9,
    Ri_NIR_f = 9999.9, Ri_TIR_f = 9999.9, Ri_custom_f = 9999.9)

    param_A =
    promote(
        T, Wind, P, Rh, Cₐ, e, eₛ, VPD, ρ, λ,γ, ε,Δ, clearness, Ri_SW_f, Ri_PAR_f,
        Ri_NIR_f, Ri_TIR_f, Ri_custom_f
    )

    Atmosphere(date, duration, param_A...)
end

"""
    Weather(D <: AbstractArray{<:AbstractAtmosphere}[, S])
    Weather(df::DataFrame[, mt])

Defines the weather, *i.e.* the local conditions of the Atmosphere for one or more time-steps.
Each time-step is described using the [`Atmosphere`](@ref) structure.

The simplest way to instantiate a `Weather` is to use a `DataFrame` as input.

The `DataFrame` should be formated such as each row is an observation for a given time-step
and each column is a variable. The column names should match exactly the field names of the
[`Atmosphere`](@ref) structure, `i.e.`:

```@example
fieldnames(Atmosphere)
```

## See also

- the [`Atmosphere`](@ref) structure
- the [`read_weather`](@ref) function to read Archimed-formatted meteorology data.

## Examples

```julia
# Example of weather data defined by hand (cumbersome):
w = Weather(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ],
    (
        site = "Test site",
        important_metadata = "this is important and will be attached to our weather data"
    )
)

# Example using a DataFrame, that you would usually import from a file:
using CSV, DataFrames
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","meteo.csv")
df = CSV.read(file, DataFrame; header=5, datarow = 6)
# Select and rename the variables:
select!(df, :date, :VPD, :temperature => :T, :relativeHumidity => :Rh, :wind => :Wind, :atmosphereCO2_ppm => :Cₐ)
df[!,:duration] = 1800 # Add the time-step duration, 30min

# Make the weather, and add some metadata:
Weather(df, (site = "Aquiares", file = file))
```
"""
struct Weather{D <: AbstractArray{<:AbstractAtmosphere},S <: MutableNamedTuple}
    data::D
    metadata::S
end

function Weather(df::T) where T <: AbstractArray{<:AbstractAtmosphere}
    Weather(df, MutableNamedTuple())
end

function Weather(df::T, mt::S) where {T <: AbstractArray{<:AbstractAtmosphere},S <: NamedTuple}
    Weather(df, MutableNamedTuple(), MutableNamedTuple(;mt...))
end

function Weather(df::DataFrame, mt::S) where S <: MutableNamedTuple
    Weather([Atmosphere(; i...) for i in eachrow(df)], mt)
end

function Weather(df::DataFrame, mt::S) where S <: NamedTuple
    mt = MutableNamedTuple(;mt...)
    Weather([Atmosphere(; i...) for i in eachrow(df)], mt)
end

function Weather(df::DataFrame, dict::S) where S <: AbstractDict
    # There must be a better way for transforming a Dict into a MutableNamedTuple...
    Weather(df, MutableNamedTuple(; NamedTuple{Tuple(Symbol.(keys(dict)))}(values(dict))...))
end

function Weather(df::DataFrame)
    Weather(df, MutableNamedTuple())
end

function Base.show(io::IO, n::Weather)
    printstyled(io, "Weather data.\n", bold = true, color = :green)
    printstyled(io, "Metadata: `$(NamedTuple(n.metadata))`.\n", color = :cyan)
    printstyled(io, "Data:\n", color = :green)
    # :normal, :default, :bold, :black, :blink, :blue, :cyan, :green, :hidden, :light_black, :light_blue, :light_cyan, :light_green, :light_magenta, :light_red, :light_yellow, :magenta, :nothing, :red,
#   :reverse, :underline, :white, or :yellow
    print(DataFrame(n))
    return nothing
end

Base.getindex(w::Weather, i::Integer) = w.data[i]

"""
    DataFrame(data::Weather)

Transform a Weather type into a DataFrame.

See also [`Weather`](@ref) to make the reverse.
"""
function DataFrame(data::Weather)
return DataFrame(data.data)
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
    γ = (Cₚ * P) / (ε * λ)
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
function latent_heat_vaporization(Tₐ, λ₀)
  λ₀ - 2.365e3 * Tₐ
end

function latent_heat_vaporization(Tₐ)
    latent_heat_vaporization(Tₐ, Constants().λ₀)
end
