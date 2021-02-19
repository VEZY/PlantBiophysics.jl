
"""
Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980;
von Caemmerer and Farquhar, 1981).

The definition:

- `Tᵣ`: the reference temperature (°C) at which other parameters were measured
- `VcMaxRef`: maximum rate of Rubisco activity (``μmol\\ m^{-2}\\ s^{-1}``)
- `JMaxRef`: potential rate of electron transport (``μmol\\ m^{-2}\\ s^{-1}``)
- `RdRef`: mitochondrial respiration in the light at reference temperature (``μmol\\ m^{-2}\\ s^{-1}``)
- `Eₐᵣ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise for Rd.
- `O₂`: intercellular dioxygen concentration (``ppm``)
- `Eₐⱼ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise for JMax.
- `Hdⱼ`: rate of decrease of the function above the optimum (also called EDVJ) for JMax.
- `Δₛⱼ`: entropy factor for JMax.
- `Eₐᵥ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise for VcMax.
- `Hdᵥ`: rate of decrease of the function above the optimum (also called EDVC) for VcMax.
- `Δₛᵥ`: entropy factor for VcMax.
- `α`: quantum yield of electron transport (``mol_e\\ mol^{-1}_{quanta}``). See also eq. 4 of
Medlyn et al. (2002) and its implementation in [`get_J`](@ref)
- `θ`: determines the curvature of the light response curve for `J~PPFD`. See also eq. 4 of
Medlyn et al. (2002) and its implementation in [`get_J`](@ref)

The default values of the temperature correction parameters are taken from
[plantecophys](https://remkoduursma.github.io/plantecophys/). If there is no negative effect
of high temperatures on the reaction (Jmax or VcMax), then Δₛ can be set to 0.0.

# Note

Medlyn et al. (2002) found relatively low influence ("a slight effect") of α and θ. They also
say that Kc, Ko and Γ* "are thought to be intrinsic properties of the Rubisco enzyme
and are generally assumed constant among species".

# See also

- [`get_J`](@ref)
- [`assimilation`](@ref)

# References

Caemmerer, S. von, et G. D. Farquhar. 1981. « Some Relationships between the Biochemistry of
Photosynthesis and the Gas Exchange of Leaves ». Planta 153 (4): 376‑87.
https://doi.org/10.1007/BF00384257.

Farquhar, G. D., S. von von Caemmerer, et J. A. Berry. 1980. « A biochemical model of
photosynthetic CO2 assimilation in leaves of C3 species ». Planta 149 (1): 78‑90.

Medlyn, B. E., E. Dreyer, D. Ellsworth, M. Forstreuter, P. C. Harley, M. U. F. Kirschbaum,
X. Le Roux, et al. 2002. « Temperature response of parameters of a biochemically based model
of photosynthesis. II. A review of experimental data ». Plant, Cell & Environment 25 (9): 1167‑79.
https://doi.org/10.1046/j.1365-3040.2002.00891.x.

# Examples

```julia
Get the fieldnames:
fieldnames(Fvcb)
# Using default values for the model:
A = Fvcb()

A.Eₐᵥ
```
"""
Base.@kwdef struct Fvcb{T} <: AbstractAModel
    Tᵣ::T = 25.0
    VcMaxRef::T = 200.0
    JMaxRef::T = 250.0
    RdRef::T = 0.6
    Eₐᵣ::T = 46390.0
    O₂::T = 210.0
    Eₐⱼ::T = 29680.0
    Hdⱼ::T = 200000.0
    Δₛⱼ::T = 631.88
    Eₐᵥ::T = 58550.0
    Hdᵥ::T = 200000.0
    Δₛᵥ::T = 629.26
    α::T = 0.425
    θ::T = 0.90
end

function variables(::Fvcb)
    (:A,:Gₛ,:Cᵢ,:Tₗ,:PPFD,:Cₛ)
end

"""
    assimilation!(leaf::Leaf{G,I,E,<:Fvcb,<:AbstractGsModel,S},constants = Constants())

Photosynthesis using the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis
 (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981).
Computation is made following Farquhar & Wong (1984), Leuning et al. (1995), and the
MAESPA model (Duursma et al., 2012).
The resolution is analytical as first presented in Baldocchi (1994), and needs Cₛ as input.

If you prefer to use Gbc, you can use the iterative implementation of the Fvcb model
[`FvcbIter`](@ref)

# Returns

Modify the first argument in place for A, Gₛ and Cᵢ:

- A: carbon assimilation (μmol[CO₂] m-2 s-1)
- Gₛ: stomatal conductance for CO₂ (mol[CO₂] m-2 s-1)
- Cᵢ: intercellular CO₂ concentration (ppm)

# Arguments

- `leaf::Leaf{.,.,.,<:Fvcb,<:AbstractGsModel,.}`: A [`Leaf`](@ref) struct holding the parameters for
the model with initialisations for:
    - `Tₗ` (°C): leaf temperature
    - `PPFD` (μmol m-2 s-1): absorbed Photosynthetic Photon Flux Density
    - `Cₛ` (mol m-2 s-1): surface CO₂ concentration.
    - `Dₗ` (mol m-2 s-1): vapour pressure difference between the surface and the air saturation
    vapour pressure in case you're using the stomatal conductance model of [`Medlyn`](@ref).
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

# Note

`Tₗ`, `PPFD`, `Cₛ` (and `Dₗ` if you use [`Medlyn`](@ref)) must be initialised by providing
them as keyword arguments (see examples). If in doubt, it is simpler to compute the energy
balance of the leaf with the photosynthesis to get those variables. See
[`energy_balance`](@ref) for more details.

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = Leaf(photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = meteo.VPD)
# NB: we need  to initalise Tₗ, PPFD and Cₛ

assimilation!(leaf,meteo,Constants())
leaf.status.A
leaf.status.Cᵢ
```

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

Leuning, R., F. M. Kelliher, DGG de Pury, et E.D. Schulze. 1995. « Leaf nitrogen,
photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant,
Cell & Environment 18 (10): 1183‑1200.
"""
function assimilation!(leaf::Leaf{G,I,E,<:Fvcb,<:AbstractGsModel,S}, meteo, constants = Constants()) where {G,I,E,S}

    # Tranform Celsius temperatures in Kelvin:
    Tₖ = leaf.status.Tₗ - constants.K₀
    Tᵣₖ = leaf.photosynthesis.Tᵣ - constants.K₀

    # Temperature dependence of the parameters:
    Γˢ = Γ_star(Tₖ,Tᵣₖ,constants.R) # Gamma star (CO2 compensation point) in μmol mol-1
    Km = get_km(Tₖ,Tᵣₖ,leaf.photosynthesis.O₂,constants.R) # effective Michaelis–Menten coefficient for CO2

    # Maximum electron transport rate at the given leaf temperature (μmol m-2 s-1):
    JMax = arrhenius(leaf.photosynthesis.JMaxRef,leaf.photosynthesis.Eₐⱼ,Tₖ,Tᵣₖ,
                        leaf.photosynthesis.Hdⱼ,leaf.photosynthesis.Δₛⱼ,constants.R)
    # Maximum rate of Rubisco activity at the given leaf temperature (μmol m-2 s-1):
    VcMax = arrhenius(leaf.photosynthesis.VcMaxRef,leaf.photosynthesis.Eₐᵥ,Tₖ,Tᵣₖ,
                        leaf.photosynthesis.Hdᵥ,leaf.photosynthesis.Δₛᵥ,constants.R)
    # Rate of mitochondrial respiration at the given leaf temperature (μmol m-2 s-1):
    Rd = arrhenius(leaf.photosynthesis.RdRef,leaf.photosynthesis.Eₐᵣ,Tₖ,Tᵣₖ,constants.R)
    # Rd is also described as the CO2 release in the light by processes other than the PCO
    # cycle, and termed "day" respiration, or "light respiration" (Harley et al., 1986).

    # Actual electron transport rate (considering intercepted PAR and leaf temperature):
    J = get_J(leaf.status.PPFD, JMax, leaf.photosynthesis.α, leaf.photosynthesis.θ) # in μmol m-2 s-1
    # RuBP regeneration
    Vⱼ = J / 4

    # Stomatal conductance (mol[CO₂] m-2 s-1), dispatched on type of first argument (Gs_mod):
    gs_mod = gs_closure(leaf,meteo)

    Cᵢⱼ = get_Cᵢⱼ(Vⱼ,Γˢ,leaf.status.Cₛ,Rd,leaf.stomatal_conductance.g0,gs_mod)

    # Electron-transport-limited rate of CO2 assimilation (RuBP regeneration-limited):
    Wⱼ = Vⱼ * (Cᵢⱼ - Γˢ) / (Cᵢⱼ + 2.0 * Γˢ) # also called Aⱼ
    # See Von Caemmerer, Susanna. 2000. Biochemical models of leaf photosynthesis.
    # Csiro publishing, eq. 2.23.
    # NB: here the equation is modified because we use Vⱼ instead of J, but it is the same.

    # If Rd is larger than Wⱼ, no assimilation:
    if Wⱼ - Rd < 1.0e-6
        Cᵢⱼ = Γˢ
        Wⱼ = Vⱼ * (Cᵢⱼ - Γˢ) / (Cᵢⱼ + 2.0 * Γˢ)
    end

    Cᵢᵥ = get_Cᵢᵥ(VcMax,Γˢ,leaf.status.Cₛ,Rd,leaf.stomatal_conductance.g0,gs_mod,Km)

    # Rubisco-carboxylation-limited rate of CO₂ assimilation (RuBP activity-limited):
    if Cᵢᵥ <= 0.0 || Cᵢᵥ > leaf.status.Cₛ
        Wᵥ = 0.0
    else
        Wᵥ = VcMax * (Cᵢᵥ - Γˢ) / (Cᵢᵥ + Km)
    end

    # Net assimilation (μmol m-2 s-1)
    leaf.status.A = min(Wᵥ,Wⱼ) - Rd

    # Stomatal conductance (mol[CO₂] m-2 s-1)
    leaf.status.Gₛ = gs(leaf,gs_mod)

    # Intercellular CO₂ concentration (Cᵢ, μmol mol)
    leaf.status.Cᵢ = min(leaf.status.Cₛ, leaf.status.Cₛ - leaf.status.A / leaf.status.Gₛ)
    nothing
end

# With keyword arguments (better for users)
# function assimilation(A_mod::Fvcb, Gs_mod::AbstractGsModel; Tₗ, PPFD, Cₛ, Rh = missing,
#                         VPD = missing, ψₗ = missing)

#     environment = MutableNamedTuple(Tₗ = Tₗ, PPFD = PPFD, Rh = Rh, Cₛ= Cₛ, VPD = VPD, ψₗ = ψₗ)

#     assimilation(A_mod,Gs_mod,environment,Constants())
# end


"""
Rate of electron transport J (``μmol\\ m^{-2}\\ s^{-1}``), computed using the smaller root
of the quadratic equation (eq. 4 from Medlyn et al., 2002):

    θ * J² - (α * PPFD + JMax) * J + α * PPFD * JMax

NB: we use the smaller root because considering the range of values for θ and α (quite stable),
and PPFD and JMax, the function always tends to JMax with high PPFD with the smaller root (behavior we
are searching), and the opposite with the larger root.

# Returns

A tuple with (A, Gₛ, Cᵢ):

- A: carbon assimilation (μmol m-2 s-1)
- Gₛ: stomatal conductance (mol m-2 s-1)
- Cᵢ: intercellular CO₂ concentration (ppm)
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

Von Caemmerer, Susanna. 2000. Biochemical models of leaf photosynthesis. Csiro publishing.

# Examples

```jldoctest; setup = :(using PlantBiophysics)
# Using default values for the model:
julia> A = Fvcb()
Fvcb{Float64}(25.0, 200.0, 250.0, 0.6, 46390.0, 210.0, 29680.0, 200000.0, 631.88, 58550.0, 200000.0, 629.26, 0.425, 0.9)

julia> PlantBiophysics.get_J(1500, A.JMaxRef, A.α, A.θ)
236.11111111111111
```
"""
function get_J(PPFD, JMax, α, θ)
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
- `gs_mod`: stomatal conductance term computed from a given implementation of a Gs model,
e.g. [`Medlyn`](@ref).


# References

Duursma, R. A., et B. E. Medlyn. 2012. « MAESPA: a model to study interactions between water
limitation, environmental drivers and vegetation function at tree and stand levels, with an
example application to [CO2] × drought interactions ». Geoscientific Model Development 5
(4): 919‑40. https://doi.org/10.5194/gmd-5-919-2012.

Wang and Leuning, 1998
"""
function get_Cᵢⱼ(Vⱼ,Γˢ,Cₛ,Rd,g0,gs_mod)
    a = g0 + gs_mod * (Vⱼ - Rd)
    b = (1.0 - Cₛ * gs_mod) * (Vⱼ - Rd) + g0 * (2.0 * Γˢ - Cₛ) -
        gs_mod * (Vⱼ * Γˢ + 2.0 * Γˢ * Rd)
    c = -(1.0 - Cₛ * gs_mod) * Γˢ * (Vⱼ + 2.0 * Rd) -
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
- `gs_mod`: stomatal conductance term computed from a given implementation of a Gs model,
e.g. [`Medlyn`](@ref).
- `Km`: effective Michaelis–Menten coefficient for CO2 (``μ mol\\ mol^{-1}``)
"""
function get_Cᵢᵥ(VcMAX,Γˢ,Cₛ,Rd,g0,gs_mod,Km)
    a = g0 + gs_mod * (VcMAX - Rd)
    b = (1.0 - Cₛ * gs_mod) * (VcMAX - Rd) + g0 * (Km - Cₛ) - gs_mod * (VcMAX * Γˢ + Km * Rd)
    c = -(1.0 - Cₛ * gs_mod) * (VcMAX * Γˢ + Km * Rd) - g0 * Km * Cₛ

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
