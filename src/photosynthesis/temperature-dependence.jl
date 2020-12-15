"""
    arrhenius(A,Eₐ,R,Tₖ,Tᵣₖ,constants)

The Arrhenius function for dependence of the rate constant of a chemical reaction.

# Arguments

- `A`: the pre-exponential factor, a constant for each chemical reaction
- `Eₐ`: the activation energy for the reaction (``J\\ mol^{-1}``)
- `Tₖ`: is the temperature (Kelvin)
- `Tᵣₖ`: the reference temperature (Kelvin) at which A was measured
- `constants`: a struct with the values for (see [`Constants`](@ref)):
    - `R`: is the universal gas constant (``J\\ mol^{-1}\\ K^{-1}``)

# Examples

```julia
# Importing physical constants
constants = Constants()
# Using default values for the model:
A = Fvcb()

# Computing Jmax:
arrhenius(A.JMaxRef,,A.Eₐⱼ,28.0-constants.K₀,A.Tᵣ-constants.K₀,constants)
# ! Warning: temperatures must be given in Kelvin

# Computing Vcmax:
arrhenius(A.VcMaxRef,A.Eₐᵥ,28.0-constants.K₀,A.Tᵣ-constants.K₀,constants)

```
"""
function arrhenius(A,Eₐ,Tₖ,Tᵣₖ,constants)
    A * exp(Eₐ * (Tₖ - Tᵣₖ) / (constants.R * Tₖ * Tᵣₖ))
end


"""
    arrhenius(A,Eₐ,Tₖ,Tᵣₖ,constants,Hd,Δₛ)

The Arrhenius function for dependence of the rate constant of a chemical reaction,
modified following equation (17) from Medlyn et al. (2002) to consider the negative effect of
very high temperatures.

# Arguments

- `A`: the pre-exponential factor, a constant for each chemical reaction
- `Eₐ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise
 of the function (Ha in the equation of Medlyn et al. (2002))
- `Tₖ`: current temperature (Kelvin)
- `Tᵣₖ`: reference temperature (Kelvin) at which A was measured
- `Hd`: rate of decrease of the function above the optimum (called EDVJ in
[MAESPA](http://maespa.github.io/) and [plantecophys](https://remkoduursma.github.io/plantecophys/))
- `Δₛ`: entropy factor
- `constants`: a struct with the values for (see [`Constants`](@ref)):
    - `R`: is the universal gas constant (``J\\ mol^{-1}\\ K^{-1}``)

References

Medlyn, B. E., E. Dreyer, D. Ellsworth, M. Forstreuter, P. C. Harley, M. U. F. Kirschbaum,
X. Le Roux, et al. 2002. « Temperature response of parameters of a biochemically based model
of photosynthesis. II. A review of experimental data ». Plant, Cell & Environment 25 (9): 1167‑79.
https://doi.org/10.1046/j.1365-3040.2002.00891.x.


# Examples

```julia
# Importing physical constants
constants = Constants()
# Using default values for the model:
A = Fvcb()

# Computing Jmax:
arrhenius(A.JMaxRef,28.0-constants.K₀,A.Tᵣ-constants.K₀,A.Eₐⱼ,A.Hdⱼ,A.Δₛⱼ,constants)
# ! Warning: temperatures must be given in Kelvin

# Computing Vcmax:
arrhenius(A.VcMaxRef,28.0-constants.K₀,A.Tᵣ-constants.K₀,A.Eₐᵥ,A.Hdᵥ,A.Δₛᵥ,constants)

```
"""
function arrhenius(A,Eₐ,Tₖ,Tᵣₖ,constants,Hd,Δₛ)
    # Equation split in 3 parts for readability:
    ftk1 = arrhenius(A,Eₐ,Tₖ,Tᵣₖ,constants)
    ftk2 = (1.0 + exp((Tᵣₖ * Δₛ - Hd) / (Tᵣₖ * constants.R)))
    ftk3 = (1.0 + exp((Tₖ * Δₛ - Hd) / (Tₖ * constants.R)))

    ftk = ftk1 * ftk2 / ftk3

    return ftk
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
# Importing the physical constants:
constants = Constants()
# computing the temperature dependence of γˢ:
Γ_star(28-constants.K₀,25-constants.K₀,constants())
```
"""
function Γ_star(Tₖ,Tᵣₖ,constants)
    arrhenius(42.75,37830.0,Tₖ,Tᵣₖ,constants)
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
function Km(Tₖ,Tᵣₖ,O₂,constants)
    KC = arrhenius(404.9,79430.0,Tₖ,Tᵣₖ,constants)
    KO = arrhenius(278.4,36380.0,Tₖ,Tᵣₖ,constants)
    return KC * (1.0 + O₂/KO)
end
