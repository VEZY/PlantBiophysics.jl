
"""
    assimiliation(A::Fvcb,Gs::GsModel)

Photosynthesis using the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis
 (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981).
Computation is made following Farquhar & Wong (1984), Leuning et al. (1995), and the
MAESPA model (Duursma et al., 2012).
The resolution is analytical as first presented in Baldocchi (1994).

# References

Baldocchi, Dennis. 1994. « An analytical solution for coupled leaf photosynthesis and
stomatal conductance models ». Tree Physiology 14 (7-8‑9): 1069‑79.
https://doi.org/10.1093/treephys/14.7-8-9.1069.

Duursma, R. A., et B. E. Medlyn. 2012. « MAESPA: a model to study interactions between water
limitation, environmental drivers and vegetation function at tree and stand levels, with an
example application to [CO2] × drought interactions ». Geoscientific Model Development 5
(4): 919‑40. https://doi.org/10.5194/gmd-5-919-2012.

Farquhar, G. D., S. von von Caemmerer, et J. A. Berry. 1980. « A biochemical model of
photosynthetic CO2 assimilation in leaves of C3 species ». Planta 149 (1): 78‑90.

Leuning, R., F. M. Kelliher, DGG de Pury, et E.-D. SCHULZE. 1995. « Leaf nitrogen,
photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant,
Cell & Environment 18 (10): 1183‑1200.

"""
function assimiliation(A::Fvcb,Gs::GsModel,constants)
    # Inputs to add: T, PPFD, VPD, Cₛ

    # Tranform Celsius temperatures in Kelvin:
    Tₖ = T - constants.K₀
    Tᵣₖ = A.Tᵣ - constants.K₀

    # Temperature dependence of the parameters:
    Γˢ = Γ_star(Tₖ,Tᵣₖ,constants) # Gamma star (CO2 compensation point) in μmol mol-1
    Km = Km(Tₖ,Tᵣₖ,A.O₂,constants) # effective Michaelis–Menten coefficient for CO2

    # Maximum electron transport rate at the given leaf temperature (μmol m-2 s-1):
    JMax = arrhenius(A.JMaxRef,A.Eₐⱼ,Tₖ,Tᵣₖ,constants,A.Hdⱼ,A.Δₛⱼ)
    # Maximum rate of Rubisco activity at the given leaf temperature (μmol m-2 s-1):
    VcMax = arrhenius(A.VcMaxRef,A.Eₐᵥ,Tₖ,Tᵣₖ,constants,A.Hdᵥ,A.Δₛᵥ)
    # Rate of mitochondrial respiration at the given leaf temperature (μmol m-2 s-1):
    Rd = arrhenius(A.RdRef,A.Eₐᵣ,Tₖ,Tᵣₖ,constants)
    # Rd is also described as the CO2 release in the light by processes other than the PCO
    # cycle, and termed "day" respiration, or "light respiration" (Harley et al., 1986).

    # Actual electron transport rate (considering intercepted PAR and leaf temperature):
    J = J(PPFD, JMax, A.α, A.θ) # in μmol m-2 s-1
    # RuBP regeneration
    Vⱼ = J / 4

    # ! NB: Replace by a call to the conductance model:
    GSDIVA = (1.0 + Gs.g1 / sqrt(VPD)) / Cₛ

    Cᵢⱼ = Cᵢⱼ(Vⱼ,Γˢ,Cₛ,Rd,Gs.g0,GSDIVA)
    Wⱼ = Vⱼ * (Cᵢⱼ - Γˢ) / (Cᵢⱼ + 2.0 * Γˢ)

    if Wⱼ - Rd < 1.0e-6
        Cᵢⱼ = Cₛ
        Wⱼ = Vⱼ * (Cᵢⱼ - Γˢ) / (Cᵢⱼ + 2.0 * Γˢ)
    end

    Cᵢᵥ = Cᵢᵥ(VcMAX,Γˢ,Cₛ,Rd,Gs.g0,GSDIVA,Km)

    if Cᵢᵥ <= 0.0 | Cᵢᵥ > Cₛ
        Wᵥ = 0.0
    else
        Wᵥ = VcMax * (Cᵢᵥ - Γˢ) / (Cᵢᵥ + Km)
    end

    # Net assimilation (μmol m-2 s-1)
    A = min(Wᵥ,Wⱼ) - Rd

    # Stomatal conductance (μmol m-2 s-1)
    Gₛ = g0 + GSDIVA * A

    # Intercellular CO₂ concentration (Cᵢ, μmol mol)
    if Gₛ > 0.0 & A > 0.0
        Cᵢ = Cₛ - A / Gₛ
    else
        Cᵢ = Cₛ
    end

    return (A, Gₛ, Cᵢ)
end

"""
Photosynthesis using the Farquhar–von Caemmerer–Berry (FvCB) model with
default constant values (found in [`Constants`](@ref)).
"""
function assimiliation(A::Fvcb,Gs::GsModel)
    assimiliation(A,Gs,Constants())
end

"""
Rate of electron transport J (``μmol\\ m^{-2}\\ s^{-1}``), computed using the smaller root
of the quadratic equation (eq. 4 from Medlyn et al., 2002):

    θ * J² - (α * PPFD + JMax) * J + α * PPFD * JMax

NB: we use the smaller root because considering the range of values for θ and α (quite stable),
and PPFD and JMax, the function always tends to JMax with high PPFD with the smaller root (behavior we
are searching), and the opposite with the larger root.

# Arguments

- `PPFD`: absorbed photon irradiance (``μmol_{quanta}\\ m^{-2}\\ s^{-1}``)
- `α`: quantum yield of electron transport (``mol_e\\ mol^{-1}_{quanta}``)
- `JMax`: maximum rate of electron transport (``μmol\\ m^{-2}\\ s^{-1}``)
- `θ`: determines the shape of the non-rectangular hyperbola (-)

# References

Medlyn, B. E., E. Dreyer, D. Ellsworth, M. Forstreuter, P. C. Harley, M. U. F. Kirschbaum,
X. Le Roux, et al. 2002. « Temperature response of parameters of a biochemically based model
of photosynthesis. II. A review of experimental data ». Plant, Cell & Environment 25 (9): 1167‑79.
https://doi.org/10.1046/j.1365-3040.2002.00891.x.

# Examples

```jldoctest
# Using default values for the model:
julia> A = Fvcb();
julia> PlantBiophysics.J(1500, A.JMaxRef, A.α, A.θ)
236.11111111111111

# Plotting J~PPFD (simplification here, JMax = JMaxRef):
julia> using Plots
julia> PPFD = 0:100:2000
julia> plot(x -> PlantBiophysics.J(x, A.JMaxRef, A.α, A.θ), PPFD, xlabel = "PPFD (μmol m⁻² s⁻¹)",
            ylab = "J (μmol m⁻² s⁻¹)", label = "Default values", legend = :bottomright)
julia> plot!(x -> PlantBiophysics.J(x, A.JMaxRef, A.α, A.θ * 0.5), PPFD, label = "θ * 0.5")
julia> plot!(x -> PlantBiophysics.J(x, A.JMaxRef, A.α * 0.5, A.θ), PPFD, label = "α * 0.5")
```
"""
function J(PPFD, JMax, α, θ)
  (α * PPFD + JMax - sqrt((α * PPFD + JMax)^2 - 4 * α * θ * PPFD * JMax)) / (2 * θ)
end

"""
Analytic resolution of Cᵢ when the rate of electron transport is limiting (``μmol\\ mol^{-1}``)

# Arguments

- `Vⱼ`: RuBP regeneration (J/4.0, ``μmol\\ m^{-2}\\ s^{-1}``)
- `Γˢ`: CO2 compensation point ``Γ^⋆`` (``μmol\\ mol^{-1}``)
- `Cₛ`: stomatal CO₂ concentration (``μmol\\ mol^{-1}``)
- `Rd`: day respiration (``μmol\\ m^{-2}\\ s^{-1}``)
- `g0`: residual stomatal conductance (``μmol\\ m^{-2}\\ s^{-1}``)
- `GSDIVA`: stomatal conductance term.
"""
function Cᵢⱼ(Vⱼ,Γˢ,Cₛ,Rd,g0,GSDIVA)
    a = g0 + GSDIVA * (Vⱼ - Rd)
    b = (1.0 - Cₛ * GSDIVA) * (Vⱼ - Rd) + g0 * (2.0 * Γˢ - Cₛ) -
        GSDIVA * (Vⱼ * Γˢ + 2.0 * Γˢ * Rd)
    c = -(1.0 - Cₛ * GSDIVA) * Γˢ * (Vⱼ + 2.0 * Rd) -
        g0 * 2.0 * Γˢ * Cₛ

    return max_root(a,b,c)
end

"""
Analytic resolution of Cᵢ when the Rubisco activity is limiting (``μmol\\ mol^{-1}``)

# Arguments

- `VcMAX`: maximum rate of Rubisco activity(``μmol\\ m^{-2}\\ s^{-1}``)
- `Γˢ`: CO2 compensation point ``Γ^⋆`` (``μmol\\ mol^{-1}``)
- `Cₛ`: stomatal CO₂ concentration (``μmol\\ mol^{-1}``)
- `Rd`: day respiration (``μmol\\ m^{-2}\\ s^{-1}``)
- `g0`: residual stomatal conductance (``μmol\\ m^{-2}\\ s^{-1}``)
- `GSDIVA`: stomatal conductance term.
- `Km`: effective Michaelis–Menten coefficient for CO2 (``μ mol\\ mol^{-1}``)
"""
function Cᵢᵥ(VcMAX,Γˢ,Cₛ,Rd,g0,GSDIVA,Km)
    a = g0 + GSDIVA * (VcMAX - Rd)
    b = (1.0 - Cₛ * GSDIVA) * (VcMAX - Rd) + g0 * (Km - Cₛ) - GSDIVA * (VcMAX * Γˢ + Km * Rd)
    c = -(1.0 - Cₛ * GSDIVA) * (VcMAX * Γˢ + Km * Rd) - g0 * Km * Cₛ

    return max_root(a,b,c)
end

"""
Maximum value between two roots of a quadratic equation.
"""
function max_root(a,b,c)
    Δ = b^2.0 - 4.0 * a * c
    x1 = (-b + sqrt(Δ)) / (2.0 * a)
    x2 = (-b - sqrt(Δ)) / (2.0 * a)
    return max(x1,x2)
end
