"""
    arrhenius(A,Eₐ,R,T,Tᵣ,constants)

The Arrhenius function for dependence of the rate constant of a chemical reaction.

# Arguments

- `A`: the pre-exponential factor, a constant for each chemical reaction
- `Eₐ`: the activation energy for the reaction (``J\\ mol^{-1}``)
- `T`: is the temperature (°C)
- `Tᵣ`: the reference temperature (°C) at which A was measured
- `constants`: a struct with the values for (see [`Constants`](@ref)):
    - `K₀`: the absolute zero temperature (°C)
    - `R`: is the universal gas constant (``J\\ mol^{-1}\\ K^{-1}``)

# Examples

```julia
# computing the temperature dependence of γˢ:
arrhenius()
```
"""
function arrhenius(A,Eₐ,T,Tᵣ,constants)
    A * exp(Eₐ * (T - Tᵣ) / (constants.R * (T - constants.K₀) * (Tᵣ - constants.K₀)))
end


"""
Compute the CO2 compensation point ``Γ^⋆`` (``μ mol\\ mol^{-1}``) according to equation (12)
from Medlyn et al. (2002).


# References

Medlyn, B. E., E. Dreyer, D. Ellsworth, M. Forstreuter, P. C. Harley, M. U. F. Kirschbaum,
X. Le Roux, et al. 2002. « Temperature response of parameters of a biochemically based model
of photosynthesis. II. A review of experimental data ». Plant, Cell & Environment 25 (9): 1167‑79.
https://doi.org/10.1046/j.1365-3040.2002.00891.x.


# Examples

```julia
# computing the temperature dependence of γˢ:
Γ_star(28,25,constants())
```
"""
function Γ_star(T,Tᵣ,constants)
    arrhenius(42.75,37830.0,T,Tᵣ,constants)
end

"""
Compute the effective Michaelis–Menten coefficient for CO2 ``Km`` (``μ mol\\ mol^{-1}``) according to
Medlyn et al. (2002), equations (5) and (6).


# References

Medlyn, B. E., E. Dreyer, D. Ellsworth, M. Forstreuter, P. C. Harley, M. U. F. Kirschbaum,
X. Le Roux, et al. 2002. « Temperature response of parameters of a biochemically based model
of photosynthesis. II. A review of experimental data ». Plant, Cell & Environment 25 (9): 1167‑79.
https://doi.org/10.1046/j.1365-3040.2002.00891.x.


# Examples

```julia
# computing the temperature dependence of γˢ:
Km(28,25,constants())
```
"""
function Km(T,Tᵣ,O₂,constants)
    KC = arrhenius(404.9,79430.0,T,Tᵣ,constants)
    KO = arrhenius(278.4,36380.0,T,Tᵣ,constants)
    return KC * (1.0 + O₂/KO)
end


"""
Potential electron transport rate (Jmax) at the given leaf temperature following
Medlyn et al. (2002), equation (17).

# Arguments

- `JMaxRef`: value of JMax at Tᵣ (A in the Arrhenius function)
- `Eₐⱼ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise
 of the function (Ha in the equation of Medlyn et al. (2002))
- `T`: current temperature (°C)
- `Tᵣ`: reference temperature (°C) at which JMaxRef was measured
- `Hd`: rate of decrease of the function above the optimum (called EDVJ in
[MAESPA](http://maespa.github.io/) and [plantecophys](https://remkoduursma.github.io/plantecophys/))
- `Δₛⱼ`: entropy factor
- `constants`: a struct with the values for (see [`Constants`](@ref)):
    - `K₀`: the absolute zero temperature (°C)
    - `R`: is the universal gas constant (``J\\ mol^{-1}\\ K^{-1}``)

References

Medlyn, B. E., E. Dreyer, D. Ellsworth, M. Forstreuter, P. C. Harley, M. U. F. Kirschbaum,
X. Le Roux, et al. 2002. « Temperature response of parameters of a biochemically based model
of photosynthesis. II. A review of experimental data ». Plant, Cell & Environment 25 (9): 1167‑79.
https://doi.org/10.1046/j.1365-3040.2002.00891.x.


# Examples

```julia
# Using default values for the model:
A = Fvcb()
Jmax(A.JMaxRef,28,A.Tᵣ,A.Eₐⱼ,A.Hd,A.Δₛⱼ,Constants())
```
"""
function Jmax(JMaxRef,T,Tᵣ,Eₐⱼ,Hd,Δₛⱼ,constants)
    # Tranform Celsius temperatures in Kelvin:
    Tₖ = T - constants.K₀
    Tᵣₖ = Tᵣ - constants.K₀

    # Equation split in 3 parts for readability:
    ftk1 = exp(Eₐⱼ * (T - Tᵣ)  / (Tᵣₖ * constants.R * Tₖ))
    ftk2 = (1.0 + exp((Tᵣₖ * Δₛⱼ - Hd) / (Tᵣₖ * constants.R)))
    ftk3 = (1.0 + exp((Tₖ * Δₛⱼ - Hd) / (Tₖ * constants.R)))

    ftk = JMaxRef * ftk1 * ftk2 / ftk3

    return ftk
end
