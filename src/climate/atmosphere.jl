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
- `Ri_PAR_f::A = 9999.9` (W m-2): Incoming PAR flux
- `Ri_NIR_f::A = 9999.9` (W m-2): Incoming NIR flux
- `Ri_TIR_f::A = 9999.9` (W m-2): Incoming TIR flux
- `Ri_custom_f::A = 9999.9` (W m-2): Incoming radiation flux for a custom waveband

# Notes

The structure can be built using only `T`, `Rh`, `Wind` and `P`. All other variables are optional
and either let at their default value or automatically computed using the functions given in `Arguments`.

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
    T, Wind, Rh, date=Dates.now(), duration=1.0, P=101.325,
    Cₐ=400.0, e=vapor_pressure(T, Rh), eₛ=e_sat(T), VPD=eₛ - e,
    ρ=air_density(T, P), λ=latent_heat_vaporization(T),
    γ=psychrometer_constant(P, λ), ε=atmosphere_emissivity(T, e),
    Δ=e_sat_slope(T), clearness=9999.9, Ri_SW_f=9999.9, Ri_PAR_f=9999.9,
    Ri_NIR_f=9999.9, Ri_TIR_f=9999.9, Ri_custom_f=9999.9)

    # Checking some values:
    if Wind <= 0
        @warn "Wind should always be > 0, forcing it to 1e-6"
        Wind = 1e-6
    end

    if Rh <= 0
        @warn "Rh should always be > 0, forcing it to 1e-6"
        Rh = 1e-6
    end

    if Rh > 1
        if 1 < Rh < 100
            @warn "Rh should be 0 < Rh < 1, assuming it is given in % and dividing by 100"
            Rh /= 100
        else
            @error "Rh should be 0 < Rh < 1, and its value is $(Rh)"
        end
    end

    if clearness != 9999.9 && (clearness <= 0 || clearness > 1)
        @error "clearness should always be 0 < clearness < 1"
    end

    param_A =
        promote(
            T, Wind, P, Rh, Cₐ, e, eₛ, VPD, ρ, λ, γ, ε, Δ, clearness, Ri_SW_f, Ri_PAR_f,
            Ri_NIR_f, Ri_TIR_f, Ri_custom_f
        )

    Atmosphere(date, duration, param_A...)
end
