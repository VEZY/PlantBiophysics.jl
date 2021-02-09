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
function ms_to_mol(G,T,P,R,K₀)
    G * f_ms_to_mol(T,P,R,K₀)
end

function ms_to_mol(G,T,P)
    constants = Constants()
    ms_to_mol(G,T,P,constants.R,constants.K₀)
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
function mol_to_ms(G,T,P,R,K₀)
    G / f_ms_to_mol(T,P,R,K₀)
end

function mol_to_ms(G,T,P)
    constants = Constants()
    mol_to_ms(G,T,P,constants.R,constants.K₀)
end

"""
Conversion factor between conductance in ``m\\ s^{-1}`` to ``mol\\ m^{-2}\\ s^{-1}``.
"""
function f_ms_to_mol(T,P,R,K₀)
    P / (R * (T - K₀))
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
function rh_from_vpd(VPD,eₛ)
    one(VPD) - VPD / eₛ
end

"""
    gbh_to_gbw(gbh, Gbₕ_to_Gbₕ₂ₒ)
    gbh_to_gbw(gbh)

Boundary layer conductance for water vapor from boundary layer conductance for heat.

# Arguments

- `gbh` (m s-1): boundary layer conductance for heat under mixed convection.
- `Dₕ₀`: molecular diffusivity for heat at base temperature. Use value from [`Constants`](@Ref)
if not provided.

# Note

Gbₕ is the sum of free and forced convection. See [`gbₕ_free`](@ref) and [`gbₕ_forced`](@ref).
"""
function gbh_to_gbw(gbh, Gbₕ_to_Gbₕ₂ₒ)
    gbh * Gbₕ_to_Gbₕ₂ₒ
end


function gbh_to_gbw(gbh)
    gbh_to_gbw(gbh, Constants().Gbₕ_to_Gbₕ₂ₒ)
end

"""
    gsc_to_gsw(Gₛ, Gsc_to_Gsw)
    gsc_to_gsw(Gₛ)

Conversion of a stomatal conductance for CO₂ into stomatal conductance for H₂O.
"""
function gsc_to_gsw(Gₛ, Gsc_to_Gsw)
    Gₛ * Gsc_to_Gsw
end

function gsc_to_gsw(Gₛ)
        gsc_to_gsw(Gₛ, Constants().Gsc_to_Gsw)
end
