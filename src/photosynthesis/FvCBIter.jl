
"""
Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980;
von Caemmerer and Farquhar, 1981).

Iterative implementation, i.e. the assimilation is computed iteratively over Cᵢ.

For more details on arguments, see [`Fvcb`](@ref).
This structure has several more parameters:

- `iter_A_max::Int`: maximum number of iterations allowed for the iteration on the assimilation.
- `ΔT_A::T = 1`: threshold bellow which the assimilation is considered constant. Given in
percent of change, *i.e.* 1% means that two successive assimilations with less than 1%
difference in value are considered the same value.
"""
struct FvcbIter{T} <: AbstractAModel
    Tᵣ::T
    VcMaxRef::T
    JMaxRef::T
    RdRef::T
    Eₐᵣ::T
    O₂::T
    Eₐⱼ::T
    Hdⱼ::T
    Δₛⱼ::T
    Eₐᵥ::T
    Hdᵥ::T
    Δₛᵥ::T
    α::T
    θ::T
    iter_A_max::Int
    ΔT_A::T
end

function FvcbIter(; Tᵣ = 25.0, VcMaxRef = 200.0, JMaxRef = 250.0, RdRef = 0.6, Eₐᵣ = 46390.0,
    O₂ = 210.0, Eₐⱼ = 29680.0, Hdⱼ = 200000.0, Δₛⱼ = 631.88, Eₐᵥ = 58550.0, Hdᵥ = 200000.0,
    Δₛᵥ = 629.26, α = 0.425, θ = 0.90, iter_A_max = 20, ΔT_A = 1.0)

    # Add type promotion in case we want to use e.g. Measurements for one parameter only and
    # we don't want to set each parameter to ± 0 by hand.
    param_float = promote(Tᵣ, VcMaxRef, JMaxRef, RdRef, Eₐᵣ, O₂, Eₐⱼ, Hdⱼ, Δₛⱼ, Eₐᵥ, Hdᵥ, Δₛᵥ, α, θ, ΔT_A)
    FvcbIter(
        param_float[1:end-1]...,
        iter_A_max,
        param_float[end]
    )
end

function inputs(::FvcbIter)
    (:PPFD, :Tₗ, :Gbc)
end

function outputs(::FvcbIter)
    (:A, :Gₛ, :Cᵢ, :Cₛ)
end

Base.eltype(x::FvcbIter) = typeof(x).parameters[1]

"""
    photosynthesis!_(leaf::LeafModels{I,E,<:FvcbIter,<:AbstractGsModel,S}, meteo, constants = Constants())

Photosynthesis using the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis
 (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981).
Computation is made following Farquhar & Wong (1984), Leuning et al. (1995), and the
Archimed model.

Iterative implementation, i.e. the assimilation is computed iteratively over Cᵢ. For the
analytical resolution, see [`Fvcb`](@ref).

# Returns

Modify the first argument in place for A, Gₛ and Cᵢ:

- A: carbon assimilation (μmol[CO₂] m-2 s-1)
- Gₛ: stomatal conductance for CO₂ (mol[CO₂] m-2 s-1)
- Cᵢ: intercellular CO₂ concentration (ppm)

# Arguments

- `leaf::LeafModels{.,.,<:FvcbIter,<:AbstractGsModel,.}`: A [`LeafModels`](@ref) struct holding the parameters for
the model with initialisations for:
    - `Tₗ` (°C): leaf temperature
    - `PPFD` (μmol m-2 s-1): absorbed Photosynthetic Photon Flux Density
    - `Gbc` (mol m-2 s-1): boundary conductance for CO₂
    - `Dₗ` (kPa): vapour pressure difference between the surface and the saturated
    air vapour pressure in case you're using the stomatal conductance model of [`Medlyn`](@ref).
- `meteo`: meteorology structure, see [`Atmosphere`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

# Note

`Tₗ`, `PPFD`, `Gbc` (and `Dₗ` if you use [`Medlyn`](@ref)) must be initialised by providing
them as keyword arguments (see examples). If in doubt, it is simpler to compute the energy
balance of the leaf with the photosynthesis to get those variables. See
[`energy_balance`](@ref) for more details.

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = LeafModels(photosynthesis = FvcbIter(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            Tₗ = 25.0, PPFD = 1000.0, Gbc = 0.67, Dₗ = meteo.VPD)
# NB: we need  to initalise Tₗ, PPFD and Gbc.

photosynthesis!_(leaf,meteo,Constants())
leaf.status.A
leaf.status.Cᵢ
```

# References

Baldocchi, Dennis. 1994. « An analytical solution for coupled leaf photosynthesis and
stomatal conductance models ». Tree Physiology 14 (7-8‑9): 1069‑79.
https://doi.org/10.1093/treephys/14.7-8-9.1069.

Farquhar, G. D., S. von von Caemmerer, et J. A. Berry. 1980. « A biochemical model of
photosynthetic CO2 assimilation in leaves of C3 species ». Planta 149 (1): 78‑90.

Leuning, R., F. M. Kelliher, DGG de Pury, et E.D. Schulze. 1995. Leaf nitrogen,
photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant,
Cell & Environment 18 (10): 1183‑1200.
"""
function photosynthesis!_(leaf::LeafModels{I,E,<:FvcbIter,<:AbstractGsModel,S}, meteo,
    constants = Constants()) where {I,E,S}

    # Start with a probable value for Cₛ and Cᵢ:
    leaf.status.Cₛ = meteo.Cₐ
    leaf.status.Cᵢ = leaf.status.Cₛ * 0.75

    # Tranform Celsius temperatures in Kelvin:
    Tₖ = leaf.status.Tₗ - constants.K₀
    Tᵣₖ = leaf.photosynthesis.Tᵣ - constants.K₀

    # Temperature dependence of the parameters:
    Γˢ = Γ_star(Tₖ, Tᵣₖ, constants.R) # Gamma star (CO2 compensation point) in μmol mol-1
    Km = get_km(Tₖ, Tᵣₖ, leaf.photosynthesis.O₂, constants.R) # effective Michaelis–Menten coefficient for CO2

    # Maximum electron transport rate at the given leaf temperature (μmol m-2 s-1):
    JMax = arrhenius(leaf.photosynthesis.JMaxRef, leaf.photosynthesis.Eₐⱼ, Tₖ, Tᵣₖ,
        leaf.photosynthesis.Hdⱼ, leaf.photosynthesis.Δₛⱼ, constants.R)
    # Maximum rate of Rubisco activity at the given leaf temperature (μmol m-2 s-1):
    VcMax = arrhenius(leaf.photosynthesis.VcMaxRef, leaf.photosynthesis.Eₐᵥ, Tₖ, Tᵣₖ,
        leaf.photosynthesis.Hdᵥ, leaf.photosynthesis.Δₛᵥ, constants.R)
    # Rate of mitochondrial respiration at the given leaf temperature (μmol m-2 s-1):
    Rd = arrhenius(leaf.photosynthesis.RdRef, leaf.photosynthesis.Eₐᵣ, Tₖ, Tᵣₖ, constants.R)
    # Rd is also described as the CO2 release in the light by processes other than the PCO
    # cycle, and termed "day" respiration, or "light respiration" (Harley et al., 1986).

    # Actual electron transport rate (considering intercepted PAR and leaf temperature):
    J = get_J(leaf.status.PPFD, JMax, leaf.photosynthesis.α, leaf.photosynthesis.θ) # in μmol m-2 s-1
    # RuBP regeneration
    Vⱼ = J / 4

    # First iteration to initialise the values for A and Gₛ:
    # Net assimilation (μmol m-2 s-1)
    leaf.status.A = Fvcb_net_assimiliation(leaf.status.Cᵢ, Vⱼ, Γˢ, VcMax, Km, Rd)

    iter = true
    iter_inc = 1

    while iter
        # Stomatal conductance (mol[CO₂] m-2 s-1)
        leaf.status.Gₛ = gs(leaf, meteo)
        # Surface CO₂ concentration (ppm):
        leaf.status.Cₛ = min(meteo.Cₐ, meteo.Cₐ - leaf.status.A / leaf.status.Gbc)
        # Intercellular CO₂ concentration (ppm):
        leaf.status.Cᵢ = min(leaf.status.Cₛ, leaf.status.Cₛ - leaf.status.A / leaf.status.Gₛ)

        if leaf.status.Cᵢ <= zero(leaf.status.Cᵢ)
            leaf.status.Cᵢ = 1e-9
            A_new = -Rd
        else
            # Net assimilation (μmol m-2 s-1):
            A_new = Fvcb_net_assimiliation(leaf.status.Cᵢ, Vⱼ, Γˢ, VcMax, Km, Rd)
        end

        if abs(A_new - leaf.status.A) / leaf.status.A <= leaf.photosynthesis.ΔT_A ||
           iter_inc == leaf.photosynthesis.iter_A_max

            iter = false
        end

        leaf.status.A = A_new

        iter_inc += 1
    end
end

"""
    Fvcb_net_assimiliation(Cᵢ,Vⱼ,Γˢ,VcMax,Km,Rd)

Net assimilation following the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis
(Farquhar et al., 1980; von Caemmerer and Farquhar, 1981)
"""
function Fvcb_net_assimiliation(Cᵢ, Vⱼ, Γˢ, VcMax, Km, Rd)
    # Electron-transport-limited rate of CO₂ assimilation (RuBP regeneration-limited):
    Wⱼ = Vⱼ * (Cᵢ - Γˢ) / (Cᵢ + 2.0 * Γˢ)
    # See Von Caemmerer, Susanna. 2000. Biochemical models of leaf photosynthesis.
    # Csiro publishing, eq. 2.23.
    # NB: here the equation is modified because we use Vⱼ instead of J, but it is the same.

    # Rubisco-carboxylation-limited rate of CO₂ assimilation (RuBP activity-limited):
    Wᵥ = VcMax * (Cᵢ - Γˢ) / (Cᵢ + Km)

    # Net assimilation (μmol m-2 s-1):
    A = min(Wᵥ, Wⱼ) - Rd
    return A
end
