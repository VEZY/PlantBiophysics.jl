
"""
Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980;
von Caemmerer and Farquhar, 1981).

Iterative implementation, *i.e.* the assimilation is computed iteratively over Cᵢ.


$FVCB_PARAMETERS
- `iter_A_max::Int`: maximum number of iterations allowed for the iteration on the assimilation.
- `ΔT_A::T = 1`: threshold bellow which the assimilation is considered constant. Given in
percent of change, *i.e.* 1% means that two successive assimilations with less than 1%
difference in value are considered the same value.

$FVCB_NOTES
"""
struct FvcbIter{T} <: AbstractPhotosynthesisModel
    Tᵣ::T
    VcMaxRef::T
    JMaxRef::T
    RdRef::T
    TPURef::T
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

function FvcbIter(; iter_A_max=20, ΔT_A=1.0, kwargs...)
    @assert iter_A_max > 0 "iter_A_max must be greater than 0"
    @assert ΔT_A > 0 "ΔT_A must be greater than 0"
    iter_A_max = convert(Int, iter_A_max)

    params = Fvcb(; kwargs...)    # Add type promotion in case we want to use e.g. Measurements for one parameter only and
    # we don't want to set each parameter to ± 0 by hand.
    ΔT_A = convert(eltype(params), ΔT_A)

    FvcbIter{eltype(params)}(
        [getfield(params, f) for f in fieldnames(Fvcb)]...,
        iter_A_max,
        ΔT_A
    )
end

function PlantSimEngine.inputs_(::FvcbIter)
    (aPPFD=-Inf, Tₗ=-Inf, Gbc=-Inf)
end

function PlantSimEngine.outputs_(::FvcbIter)
    (A=-Inf, Gₛ=-Inf, Cᵢ=-Inf, Cₛ=-Inf)
end

Base.eltype(x::FvcbIter) = typeof(x).parameters[1]
PlantSimEngine.ObjectDependencyTrait(::Type{<:FvcbIter}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:FvcbIter}) = PlantSimEngine.IsTimeStepIndependent()

PlantSimEngine.dep(::FvcbIter) = (stomatal_conductance=AbstractStomatal_ConductanceModel,)

"""
    run!(::FvcbIter, models, status, meteo, constants=Constants())

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

- `::FvcbIter`: Farquhar–von Caemmerer–Berry (FvCB) model with iterative resolution.
- `models`: a `ModelList` struct holding the parameters for the model with
initialisations for:
    - `Tₗ` (°C): leaf temperature
    - `aPPFD` (μmol m-2 s-1): absorbed Photosynthetic Photon Flux Density
    - `Gbc` (mol m-2 s-1): boundary conductance for CO₂
    - `Dₗ` (kPa): is the difference between the vapour pressure at the leaf surface and the
    saturated air vapour pressure in case you're using the stomatal conductance model of [`Medlyn`](@ref).
- `status`: A status, usually the leaf status (*i.e.* leaf.status)
- `meteo`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

# Note

`Tₗ`, `aPPFD`, `Gbc` (and `Dₗ` if you use [`Medlyn`](@ref)) must be initialized by providing
them as keyword arguments (see examples). If in doubt, it is simpler to compute the energy
balance of the leaf with the photosynthesis to get those variables. See
[`AbstractEnergy_BalanceModel`](@ref) for more details.

# Examples

```julia
using PlantBiophysics, PlantMeteo
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf =
    ModelList(
        photosynthesis = FvcbIter(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        status = (Tₗ = 25.0, aPPFD = 1000.0, Gbc = 0.67, Dₗ = meteo.VPD)
    )
# NB: we need  to initalise Tₗ, aPPFD and Gbc.

run!(leaf,meteo,PlantMeteo.Constants())
leaf.status.A
leaf.status.Cᵢ
```

Note that we use `VPD` as an approximation of `Dₗ` here because we don't have the leaf temperature (*i.e.* `Dₗ = VPD` when `Tₗ = T`).

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
function PlantSimEngine.run!(m::FvcbIter, models, status, meteo, constants=PlantMeteo.Constants(), extra=nothing)

    # Start with a probable value for Cₛ and Cᵢ:
    status.Cₛ = meteo.Cₐ
    status.Cᵢ = status.Cₛ * 0.75
    # Tranform Celsius temperatures in Kelvin:
    Tₖ = status.Tₗ - constants.K₀
    Tᵣₖ = m.Tᵣ - constants.K₀

    # Temperature dependence of the parameters:
    Γˢ = Γ_star(Tₖ, Tᵣₖ, constants.R) # Gamma star (CO2 compensation point) in μmol mol-1
    Km = get_km(Tₖ, Tᵣₖ, m.O₂, constants.R) # effective Michaelis–Menten coefficient for CO2

    # Maximum electron transport rate at the given leaf temperature (μmol m-2 s-1):
    JMax = arrhenius(
        m.JMaxRef, m.Eₐⱼ, Tₖ, Tᵣₖ,
        m.Hdⱼ, m.Δₛⱼ, constants.R
    )
    # Maximum rate of Rubisco activity at the given leaf temperature (μmol m-2 s-1):
    VcMax = arrhenius(
        m.VcMaxRef, m.Eₐᵥ, Tₖ, Tᵣₖ,
        m.Hdᵥ, m.Δₛᵥ, constants.R
    )
    # Rate of mitochondrial respiration at the given leaf temperature (μmol m-2 s-1):
    Rd = arrhenius(m.RdRef, m.Eₐᵣ, Tₖ, Tᵣₖ, constants.R)
    # Rd is also described as the CO2 release in the light by processes other than the PCO
    # cycle, and termed "day" respiration, or "light respiration" (Harley et al., 1986).

    # Actual electron transport rate (considering intercepted PAR and leaf temperature):
    J = get_J(status.aPPFD, JMax, m.α, m.θ) # in μmol m-2 s-1
    # RuBP regeneration
    Vⱼ = J / 4

    # First iteration to initialize the values for A and Gₛ:
    # Net assimilation (μmol m-2 s-1)
    status.A = Fvcb_net_assimiliation(status.Cᵢ, Vⱼ, Γˢ, VcMax, Km, Rd, m.TPURef)

    iter = true
    iter_inc = 1

    while iter
        # Stomatal conductance (mol[CO₂] m-2 s-1)
        PlantSimEngine.run!(models.stomatal_conductance, models, status, meteo, constants, extra)

        # Surface CO₂ concentration (ppm):
        status.Cₛ = min(meteo.Cₐ, meteo.Cₐ - status.A / status.Gbc)
        # Intercellular CO₂ concentration (ppm):
        status.Cᵢ = min(status.Cₛ, status.Cₛ - status.A / status.Gₛ)

        if status.Cᵢ <= zero(status.Cᵢ)
            status.Cᵢ = 1e-9
            A_new = -Rd
        else
            # Net assimilation (μmol m-2 s-1):
            A_new = Fvcb_net_assimiliation(status.Cᵢ, Vⱼ, Γˢ, VcMax, Km, Rd, m.TPURef)
        end

        if abs(A_new - status.A) / status.A <= m.ΔT_A ||
           iter_inc == m.iter_A_max

            iter = false
        end

        status.A = A_new

        iter_inc += 1
    end
end

"""
    Fvcb_net_assimiliation(Cᵢ,Vⱼ,Γˢ,VcMax,Km,Rd)

Net assimilation following the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis
(Farquhar et al., 1980; von Caemmerer and Farquhar, 1981)
"""
function Fvcb_net_assimiliation(Cᵢ, Vⱼ, Γˢ, VcMax, Km, Rd, TPU)
    # Electron-transport-limited rate of CO₂ assimilation (RuBP regeneration-limited):
    Wⱼ = Vⱼ * (Cᵢ - Γˢ) / (Cᵢ + 2.0 * Γˢ)
    # See Von Caemmerer, Susanna. 2000. Biochemical models of leaf photosynthesis.
    # Csiro publishing, eq. 2.23.
    # NB: here the equation is modified because we use Vⱼ instead of J, but it is the same.

    # Rubisco-carboxylation-limited rate of CO₂ assimilation (RuBP activity-limited):
    Wᵥ = VcMax * (Cᵢ - Γˢ) / (Cᵢ + Km)

    ag = 0.0
    Wₚ = (Cᵢ - Γˢ) * 3 * TPU / (Cᵢ - (1 .+ 3 * ag) * Γˢ)

    # Net assimilation (μmol m-2 s-1):
    A = min(Wᵥ, Wⱼ, Wₚ) - Rd
    return A
end
