"""
    ms_to_mol(G,T,P,R,K₀)
    ms_to_mol(G,T,P)

Conversion of a conductance `G` from ``m\\ s^{-1}`` to ``mol\\ m^{-2}\\ s^{-1}``.

# Arguments

- `G` (``m\\ s^{-1}``): conductance
- `T` (°C): air temperature
- `P` (kPa): air pressure
- `R` (``J\\ mol^{-1}\\ K^{-1}``): universal gas constant.
- `K₀` (°C): absolute zero

# See also

[`mol_to_ms`](@ref) for the inverse process.
"""
function ms_to_mol(G, T, P, R, K₀)
    G * f_ms_to_mol(T, P, R, K₀)
end

function ms_to_mol(G, T, P)
    constants = Constants()
    ms_to_mol(G, T, P, constants.R, constants.K₀)
end

"""
    ms_to_mol(G,T,P,R,K₀)
    ms_to_mol(G,T,P)

Conversion of a conductance `G` from ``mol\\ m^{-2}\\ s^{-1}`` to ``m\\ s^{-1}``.

# Arguments

- `G` (``m\\ s^{-1}``): conductance
- `T` (°C): air temperature
- `P` (kPa): air pressure
- `R` (``J\\ mol^{-1}\\ K^{-1}``): universal gas constant.
- `K₀` (°C): absolute zero

# See also

[`ms_to_mol`](@ref) for the inverse process.
"""
function mol_to_ms(G, T, P, R, K₀)
    G / f_ms_to_mol(T, P, R, K₀)
end

function mol_to_ms(G, T, P)
    constants = Constants()
    mol_to_ms(G, T, P, constants.R, constants.K₀)
end

"""
Conversion factor between conductance in ``m\\ s^{-1}`` to ``mol\\ m^{-2}\\ s^{-1}``.

# Arguments

- `T` (°C): air temperature
- `P` (kPa): air pressure
- `R` (``J\\ mol^{-1}\\ K^{-1}``): universal gas constant.
- `K₀` (°C): absolute zero
"""
function f_ms_to_mol(T, P, R, K₀)
    (P * 1000) / (R * (T - K₀))
end

"""
    rh_from_vpd(VPD,eₛ)

Conversion between VPD and rh.

# Examples

```julia
eₛ = e_sat(Tₐ)
rh_from_vpd(1.5,eₛ)
```
"""
function rh_from_vpd(VPD, eₛ)
    one(VPD) - VPD / eₛ
end

"""
    rh_from_e(VPD,eₛ)

Conversion between e (kPa) and rh (0-1).

# Examples

```julia
rh_from_e(1.5,25.0)
```
"""
function rh_from_e(e, Tₐ)
    eₛ = e_sat(Tₐ)
    min(one(e), e / eₛ)
end

"""
    vpd(VPD,eₛ)

Compute vapor pressure deficit (kPa) from the air relative humidity (0-1) and temperature (°C).

The computation simply uses vpd = eₛ - e.

# Examples

```julia
vpd(0.4,25.0)
```
"""
function vpd(Rh, Tₐ)
    return e_sat(Tₐ) - vapor_pressure(Tₐ, Rh)
end


"""
    gbh_to_gbw(gbh, Gbₕ_to_Gbₕ₂ₒ = Constants().Gbₕ_to_Gbₕ₂ₒ)
    gbw_to_gbh(gbh, Gbₕ_to_Gbₕ₂ₒ = Constants().Gbₕ_to_Gbₕ₂ₒ)

Boundary layer conductance for water vapor from boundary layer conductance for heat.

# Arguments

- `gbh` (m s-1): boundary layer conductance for heat under mixed convection.
- `Gbₕ_to_Gbₕ₂ₒ`: conversion factor.

# Note

Gbₕ is the sum of free and forced convection. See [`gbₕ_free`](@ref) and [`gbₕ_forced`](@ref).
"""
function gbh_to_gbw(gbh, Gbₕ_to_Gbₕ₂ₒ=Constants().Gbₕ_to_Gbₕ₂ₒ)
    gbh * Gbₕ_to_Gbₕ₂ₒ
end

function gbw_to_gbh(gbh, Gbₕ_to_Gbₕ₂ₒ=Constants().Gbₕ_to_Gbₕ₂ₒ)
    gbh / Gbₕ_to_Gbₕ₂ₒ
end


"""
    gsc_to_gsw(Gₛ, Gsc_to_Gsw = Constants().Gsc_to_Gsw)

Conversion of a stomatal conductance for CO₂ into stomatal conductance for H₂O.
"""
function gsc_to_gsw(Gₛ, Gsc_to_Gsw=Constants().Gsc_to_Gsw)
    Gₛ * Gsc_to_Gsw
end

"""
    gsw_to_gsc(Gₛ, Gsc_to_Gsw = Constants().Gsc_to_Gsw)

Conversion of a stomatal conductance for H₂O into stomatal conductance for CO₂.
"""
function gsw_to_gsc(Gₛ, Gsc_to_Gsw=Constants().Gsc_to_Gsw)
    Gₛ / Gsc_to_Gsw
end


"""
    λE_to_E(λE, λ, Mₕ₂ₒ=Constants().Mₕ₂ₒ)
    E_to_λE(E, λ, Mₕ₂ₒ=Constants().Mₕ₂ₒ)

Conversion from latent heat (W m-2) to evaporation (mol[H₂O] m-2 s-1) or the
opposite (`E_to_λE`).

# Arguments

- `λE`: latent heat flux (W m-2)
- `E`: water evaporation (mol[H₂O] m-2 s-1)
- `λ` (J kg-1): latent heat of vaporization
- `Mₕ₂ₒ = 18.0e-3` (kg mol-1): Molar mass for water.

# Note

`λ` can be computed using:

    λ = latent_heat_vaporization(T, constants.λ₀)

It is also directly available from the [`Atmosphere`](@ref) structure, and by extention in [`Weather`](@ref).

To convert E from mol[H₂O] m-2 s-1 to mm s-1 you can simply do:

    E_mms = E_mol / constants.Mₕ₂ₒ

mm[H₂O] s-1 is equivalent to kg[H₂O] m-2 s-1, wich is equivalent to l[H₂O] m-2 s-1.

"""
function λE_to_E(λE, λ, Mₕ₂ₒ=Constants().Mₕ₂ₒ)
    λE / λ * Mₕ₂ₒ
end

function E_to_λE(E, λ, Mₕ₂ₒ=Constants().Mₕ₂ₒ)
    E / Mₕ₂ₒ * λ
end
