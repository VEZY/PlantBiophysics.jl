
"""
Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980;
von Caemmerer and Farquhar, 1981). Direct implementation of the model.

See [`Fvcb`](@ref) for more details.

# See also

- [`Fvcb`](@ref) for the coupled assimilation / conductance model
- [`FvcbIter`](@ref) for the coupled assimilation / conductance model with an iterative resolution
- [`get_J`](@ref)
- [`photosynthesis`](@ref)

# References

Caemmerer, S. von, et G. D. Farquhar. 1981. « Some Relationships between the Biochemistry of
Photosynthesis and the Gas Exchange of Leaves ». Planta 153 (4): 376‑87.
https://doi.org/10.1007/BF00384257.

Farquhar, G. D., S. von von Caemmerer, et J. A. Berry. 1980. « A biochemical model of
photosynthetic CO2 assimilation in leaves of C3 species ». Planta 149 (1): 78‑90.

# Examples

```julia
Get the fieldnames:
fieldnames(FvcbRaw)
# Using default values for the model:
A = FvcbRaw()

A.Eₐᵥ
```
"""
struct FvcbRaw{T} <: AbstractAModel
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
end

function FvcbRaw(; Tᵣ=25.0, VcMaxRef=200.0, JMaxRef=250.0, RdRef=0.6, TPURef=9999.0, Eₐᵣ=46390.0,
    O₂=210.0, Eₐⱼ=29680.0, Hdⱼ=200000.0, Δₛⱼ=631.88, Eₐᵥ=58550.0, Hdᵥ=200000.0,
    Δₛᵥ=629.26, α=0.24, θ=0.7)

    FvcbRaw(promote(Tᵣ, VcMaxRef, JMaxRef, RdRef, TPURef, Eₐᵣ, O₂, Eₐⱼ, Hdⱼ, Δₛⱼ, Eₐᵥ, Hdᵥ, Δₛᵥ, α, θ)...)
end

function inputs_(::FvcbRaw)
    (PPFD=-999.99, Tₗ=-999.99, Cᵢ=-999.99)
end

function outputs_(::FvcbRaw)
    (A=-999.99,)
end

Base.eltype(x::FvcbRaw) = typeof(x).parameters[1]

"""
    photosynthesis!_(::FvcbRaw, models, status, meteo=nothing, constants=Constants())

Direct implementation of the photosynthesis model for C3 photosynthesis from Farquhar–von
Caemmerer–Berry (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981).

# Returns

Modify the first argument in place for A, the carbon assimilation (μmol[CO₂] m-2 s-1).

# Arguments

- `::FvcbRaw`: the Farquhar–von Caemmerer–Berry (FvCB) model (not coupled)
- `models`: a [`ModelList`](@ref) struct holding the parameters for the model with
initialisations for:
    - `Tₗ` (°C): leaf temperature
    - `PPFD` (μmol m-2 s-1): absorbed Photosynthetic Photon Flux Density
    - `Cₛ` (ppm): surface CO₂ concentration.
    - `Dₗ` (kPa): vapour pressure difference between the surface and the saturated
    air vapour pressure in case you're using the stomatal conductance model of [`Medlyn`](@ref).
- `status`: A status, usually the leaf status (*i.e.* leaf.status)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

# Note

`Tₗ`, `PPFD`, `Cₛ` (and `Dₗ` if you use [`Medlyn`](@ref)) must be initialised by providing
them as keyword arguments (see examples). If in doubt, it is simpler to compute the energy
balance of the leaf with the photosynthesis to get those variables. See
[`energy_balance`](@ref) for more details.

# Examples

```julia
leaf = ModelList(photosynthesis = FvcbRaw(), status = (Tₗ = 25.0, PPFD = 1000.0, Cᵢ = 400.0))
# NB: we need Tₗ, PPFD and Cᵢ as inputs (see [`inputs`](@ref))

photosynthesis!_(leaf)
leaf.status.A
leaf.status.Cᵢ

# using several time-steps:
leaf =
    ModelList(
        photosynthesis = FvcbRaw(),
        status = (Tₗ = [20., 25.0], PPFD = 1000.0, Cᵢ = [380.,400.0])
    )
# NB: we need Tₗ, PPFD and Cᵢ as inputs (see [`inputs`](@ref))

photosynthesis!_(leaf)
DataFrame(leaf) # fetch the leaf status as a DataFrame
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

Lombardozzi, L. D. et al. 2018.« Triose phosphate limitation in photosynthesis models
reduces leaf photosynthesis and global terrestrial carbon storage ». Environmental Research
Letters 13.7: 1748-9326. https://doi.org/10.1088/1748-9326/aacf68.
"""
function photosynthesis!_(::FvcbRaw, models, status, meteo=nothing, constants=Constants())

    Tₖ = status.Tₗ - constants.K₀
    Tᵣₖ = models.photosynthesis.Tᵣ - constants.K₀
    Γˢ = Γ_star(Tₖ, Tᵣₖ, constants.R) # Gamma star (CO2 compensation point) in μmol mol-1
    Km = get_km(Tₖ, Tᵣₖ, models.photosynthesis.O₂, constants.R) # effective Michaelis–Menten coefficient for CO2
    JMax = arrhenius(models.photosynthesis.JMaxRef, models.photosynthesis.Eₐⱼ, Tₖ, Tᵣₖ, models.photosynthesis.Hdⱼ, models.photosynthesis.Δₛⱼ, constants.R)
    VcMax = arrhenius(models.photosynthesis.VcMaxRef, models.photosynthesis.Eₐᵥ, Tₖ, Tᵣₖ, models.photosynthesis.Hdᵥ, models.photosynthesis.Δₛᵥ, constants.R)
    Rd = arrhenius(models.photosynthesis.RdRef, models.photosynthesis.Eₐᵣ, Tₖ, Tᵣₖ, constants.R)
    J = get_J(status.PPFD, JMax, models.photosynthesis.α, models.photosynthesis.θ) # in μmol m-2 s-1
    Vⱼ = J / 4
    Wⱼ = Vⱼ * (status.Cᵢ - Γˢ) / (status.Cᵢ + 2.0 * Γˢ) # also called Aⱼ
    Wᵥ = VcMax * (status.Cᵢ - Γˢ) / (status.Cᵢ + Km)
    ag = 0.0
    Wₚ = (status.Cᵢ - Γˢ) * 3 * models.photosynthesis.TPURef / (status.Cᵢ - (1 .+ 3 * ag) * Γˢ)
    status.A = min(Wᵥ, Wⱼ, Wₚ) - Rd

    return status.A
end
