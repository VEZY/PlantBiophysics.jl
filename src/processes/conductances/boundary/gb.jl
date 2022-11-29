"""
    gbₕ_free(Tₐ,Tₗ,d,Dₕ₀)
    gbₕ_free(Tₐ,Tₗ,d)

Leaf boundary layer conductance for heat under **free** convection (m s-1).

# Arguments

- `Tₐ` (°C): air temperature
- `Tₗ` (°C): leaf temperature
- `d` (m): characteristic dimension, *e.g.* leaf width (see eq. 10.9 from Monteith and Unsworth, 2013).
- `Dₕ₀ = 21.5e-6`: molecular diffusivity for heat at base temperature. Use value from
[`PlantMeteo.Constants`](@ref) if not provided.

# Note

`R` and `Dₕ₀` can be found using [`PlantMeteo.Constants`](@ref). To transform in ``mol\\ m^{-2}\\ s^{-1}``,
use [`ms_to_mol`](@ref).

# References

Leuning, R., F. M. Kelliher, DGG de Pury, et E.-D. SCHULZE. 1995. « Leaf nitrogen,
photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant,
Cell & Environment 18 (10): 1183‑1200.

Monteith, John, et Mike Unsworth. 2013. Principles of environmental physics: plants,
animals, and the atmosphere. Academic Press. Paragraph 10.1.3, eq. 10.9.
"""
function gbₕ_free(Tₐ, Tₗ, d, Dₕ₀=PlantMeteo.Constants().Dₕ₀)
    zeroT = zero(Tₐ) # make it type stable

    if abs(Tₗ - Tₐ) > zeroT
        Gr = 1.58e8 * d^3.0 * abs(Tₗ - Tₐ) # Grashof number (Monteith and Unsworth, 2013)
        # !Note: Leuning et al. (1995) use 1.6e8 (eq. E4).
        # Leuning et al. (1995) eq. E3:
        Gbₕ_free = 0.5 * get_Dₕ(Tₐ, Dₕ₀) * (Gr^0.25) / d
    else
        Gbₕ_free = zeroT
    end

    return Gbₕ_free
end


"""
    gbₕ_forced(Wind,d)

Boundary layer conductance for heat under **forced** convection (m s-1). See eq. E1 from
Leuning et al. (1995) for more details.

# Arguments

- `Wind` (m s-1): wind speed
- `d` (m): characteristic dimension, *e.g.* leaf width (see eq. 10.9 from Monteith and Unsworth, 2013).

# Notes

`d` is the minimal dimension of the surface of an object in contact with the air.

# References

Leuning, R., F. M. Kelliher, DGG de Pury, et E.-D. SCHULZE. 1995. « Leaf nitrogen,
photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant,
Cell & Environment 18 (10): 1183‑1200.
"""
function gbₕ_forced(Wind, d)
    0.003 * sqrt(Wind / d)
end


"""
    get_Dₕ(T,Dₕ₀)
    get_Dₕ(T)

Dₕ -molecular diffusivity for heat at base temperature- from Dₕ₀ (corrected by temperature).
See Monteith and Unsworth (2013, eq. 3.10).

# Arguments

- `Tₐ` (°C): temperature
- `Dₕ₀`: molecular diffusivity for heat at base temperature. Use value from [`PlantMeteo.Constants`](@ref)
if not provided.

# References

Monteith, John, et Mike Unsworth. 2013. Principles of environmental physics: plants,
animals, and the atmosphere. Academic Press. Paragraph 10.1.3.
"""
function get_Dₕ(T, Dₕ₀=PlantMeteo.Constants().Dₕ₀)
    Dₕ₀ * (1 + 0.007 * T)
end
