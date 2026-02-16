FVCB_PARAMETERS = """
# Parameters

- `Tᵣ`: the reference temperature (°C) at which other parameters were measured
- `VcMaxRef`: maximum rate of Rubisco activity (``μmol\\ m^{-2}\\ s^{-1}``)
- `JMaxRef`: potential rate of electron transport (``μmol\\ m^{-2}\\ s^{-1}``)
- `RdRef`: mitochondrial respiration in the light at reference temperature (``μmol\\ m^{-2}\\ s^{-1}``)
- `TPURef`: triose phosphate utilization-limited photosynthesis rate (``μmol\\ m^{-2}\\ s^{-1}``)
- `Eₐᵣ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise for Rd.
- `O₂`: intercellular dioxygen concentration (``ppm``)
- `Eₐⱼ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise for JMax.
- `Hdⱼ`: rate of decrease of the function above the optimum (also called EDVJ) for JMax.
- `Δₛⱼ`: entropy factor for JMax.
- `Eₐᵥ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise for VcMax.
- `Hdᵥ`: rate of decrease of the function above the optimum (also called EDVC) for VcMax.
- `Δₛᵥ`: entropy factor for VcMax.
- `α`: quantum yield of electron transport (``mol_e\\ mol^{-1}_{quanta}``). See also eq. 4 of
Medlyn et al. (2002), equation 9.16 from von Caemmerer et al. (2009) ((1-f)/2) and its implementation in [`get_J`](@ref)
- `θ`: determines the curvature of the light response curve for `J~aPPFD`. See also eq. 4 of
Medlyn et al. (2002) and its implementation in [`get_J`](@ref)
"""


FVCB_NOTES = """
# Note on parameters

The default values of the temperature correction parameters are taken from
[plantecophys](https://remkoduursma.github.io/plantecophys/). If there is no negative effect
of high temperatures on the reaction (Jmax or VcMax), then Δₛ can be set to 0.0.

θ is taken at 0.7 according to (Von Caemmerer, 2000) but it can be modified to 0.9 as in (Su et al., 2009). The larger it is, the lower the smoothing.

α is taken at 0.425 as proposed in von Caemmerer et al. (2009) eq. 9.16, where α = (1-f)/2.

Medlyn et al. (2002) found relatively low influence ("a slight effect") of α and θ. They also
say that Kc, Ko and Γ* "are thought to be intrinsic properties of the Rubisco enzyme
and are generally assumed constant among species".
"""

"""
Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980;
von Caemmerer and Farquhar, 1981) coupled with a conductance model.

$FVCB_PARAMETERS

$FVCB_NOTES

# See also

- [`FvcbRaw`](@ref) for non-coupled model, directly from Farquhar et al. (1980)
- [`FvcbIter`](@ref) for the coupled assimilation / conductance model with an iterative resolution
- [`get_J`](@ref)
- [`AbstractPhotosynthesisModel`](@ref)

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

Su, Y., Zhu, G., Miao, Z., Feng, Q. and Chang, Z. 2009. « Estimation of parameters of a biochemically based
model of photosynthesis using a genetic algorithm ». Plant, Cell & Environment, 32: 1710-1723.
https://doi.org/10.1111/j.1365-3040.2009.02036.x.

Von Caemmerer, Susanna. 2000. Biochemical models of leaf photosynthesis. Csiro publishing.

Duursma, R. A. 2015. « Plantecophys - An R Package for Analysing and Modelling Leaf Gas
Exchange Data ». PLoS ONE 10(11): e0143346.
https://doi:10.1371/journal.pone.0143346.


# Examples

```julia
Get the fieldnames:
fieldnames(Fvcb)
# Using default values for the model:
A = Fvcb()

A.Eₐᵥ
```
"""
struct Fvcb{T} <: AbstractPhotosynthesisModel
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

function Fvcb(; Tᵣ=25.0, VcMaxRef=200.0, JMaxRef=250.0, RdRef=0.6, TPURef=9999.0, Eₐᵣ=46390.0,
    O₂=210.0, Eₐⱼ=29680.0, Hdⱼ=200000.0, Δₛⱼ=631.88, Eₐᵥ=58550.0, Hdᵥ=200000.0,
    Δₛᵥ=629.26, α=0.425, θ=0.7)

    Fvcb(promote(Tᵣ, VcMaxRef, JMaxRef, RdRef, TPURef, Eₐᵣ, O₂, Eₐⱼ, Hdⱼ, Δₛⱼ, Eₐᵥ, Hdᵥ, Δₛᵥ, α, θ)...)
end

function PlantSimEngine.inputs_(::Fvcb)
    (aPPFD=-Inf, Tₗ=-Inf, Cₛ=-Inf)
end

function PlantSimEngine.outputs_(::Fvcb)
    (A=-Inf, Gₛ=-Inf, Cᵢ=-Inf)
end

Base.eltype(x::Fvcb) = typeof(x).parameters[1]

PlantSimEngine.dep(::Fvcb) = (stomatal_conductance=AbstractStomatal_ConductanceModel,)
PlantSimEngine.ObjectDependencyTrait(::Type{<:Fvcb}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:Fvcb}) = PlantSimEngine.IsTimeStepIndependent()
PlantSimEngine.timestep_hint(::Type{<:Fvcb}) = (
    required=(Dates.Minute(1), Dates.Hour(6)),
    preferred=Dates.Hour(1)
)

"""
    run!(::Fvcb, models, status, meteo, constants=Constants())

Coupled photosynthesis and conductance model using the Farquhar–von Caemmerer–Berry (FvCB) model
for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981) that models
the assimilation as the most limiting factor between three processes:

- RuBisCo-limited photosynthesis, when the kinetics of the RuBisCo enzyme for fixing
CO₂ is at its maximum (RuBisCo = Ribulose-1,5-bisphosphate carboxylase-oxygenase). It happens
mostly when the CO₂ concentration in the stomata is too low. The main parameter is VcMaxRef,
the maximum rate of RuBisCo activity at reference temperature. See [`get_Cᵢᵥ`](@ref) for the
computation.

- RuBP-limited photosynthesis, when the rate of RuBP (ribulose-1,5-bisphosphate) regeneration
associated with electron transport rates on the thylakoid membrane (RuBP) is limiting. It
happens mostly when light is limiting, or when CO₂ concentration is rather high. It is
parameterized using `JMaxRef`, the potential rate of electron transport. See [`get_Cᵢⱼ`](@ref)
for the computation.

- TPU-limited photosynthesis, when the rate at which inorganic phosphate is released for
regenerating ATP from ADP during the utilization of triose phosphate (TPU) is limiting. It
happens at very high assimilation rate, when neither light or CO₂ are limiting factors. The
parameter is `TPURef`.

The computation in this function is made following Farquhar & Wong (1984), Leuning et al.
(1995), and the MAESPA model (Duursma et al., 2012).

The resolution is analytical as first presented in Baldocchi (1994), and needs Cₛ as input.

Triose phosphate utilization (TPU) limitation is taken into account as proposed in
Lombardozzi (2018) (*i.e.* `Aₚ = 3 * TPURef`, making the assumption that glycolate recycling
is set to `0`). `TPURef` is set at `9999.0` by default, meaning there is no limitation of
photosynthesis by TPU. Note that `TPURef` can be (badly) approximated using the simple
equation `TPURef = 0.167 * VcMaxRef` as presented in Lombardozzi (2018).

If you prefer to use Gbc, you can use the iterative implementation of the Fvcb model
[`FvcbIter`](@ref)

If you want a version that is de-coupled from the stomatal conductance use [`FvcbRaw`](@ref),
but you'll need Cᵢ as input of the model.

# Returns

Modify the first argument in place for A, Gₛ and Cᵢ:

- A: carbon assimilation (μmol[CO₂] m-2 s-1)
- Gₛ: stomatal conductance for CO₂ (mol[CO₂] m-2 s-1)
- Cᵢ: intercellular CO₂ concentration (ppm)

# Arguments

- `::Fvcb`: the Farquhar–von Caemmerer–Berry (FvCB) model
- `models`: a `ModelMapping` struct holding the parameters for the model with
initialisations for:
    - `Tₗ` (°C): leaf temperature
    - `aPPFD` (μmol m-2 s-1): absorbed Photosynthetic Photon Flux Density
    - `Cₛ` (ppm): Air CO₂ concentration at the leaf surface
    - `Dₗ` (kPa): vapour pressure difference between the surface and the saturated
    air vapour pressure in case you're using the stomatal conductance model of [`Medlyn`](@ref).
- `status`: A status, usually the leaf status (*i.e.* leaf.status)
- `meteo`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

# Note

`Tₗ`, `aPPFD`, `Cₛ` (and `Dₗ` if you use [`Medlyn`](@ref)) must be initialized by providing
them as keyword arguments (see examples). If in doubt, it is simpler to compute the energy
balance of the leaf with the photosynthesis to get those variables. See
[`AbstractEnergy_BalanceModel`](@ref) for more details.

# Examples

```julia
using PlantBiophysics, PlantMeteo
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf =
    ModelMapping(
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        status = (Tₗ = 25.0, aPPFD = 1000.0, Cₛ = 400.0, Dₗ = meteo.VPD)
    )
# NB: we need to initalise Tₗ, aPPFD and Cₛ.
# NB2: we provide the name of the process before the model but it is not mandatory.

run!(leaf,meteo,PlantMeteo.Constants())
leaf.status.A
leaf.status.Cᵢ
```

Note that we use `VPD` as an approximation of `Dₗ` here because we don't have the leaf temperature (*i.e.* `Dₗ = VPD` when `Tₗ = T`).

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
function PlantSimEngine.run!(m::Fvcb, models, status, meteo, constants=PlantMeteo.Constants(), extra=nothing)

    # Tranform Celsius temperatures in Kelvin:
    Tₖ = status.Tₗ - constants.K₀
    Tᵣₖ = m.Tᵣ - constants.K₀

    # Temperature dependence of the parameters:
    Γˢ = Γ_star(Tₖ, Tᵣₖ, constants.R) # Gamma star (CO2 compensation point) in μmol mol-1
    Km = get_km(Tₖ, Tᵣₖ, m.O₂, constants.R) # effective Michaelis–Menten coefficient for CO2

    # Maximum electron transport rate at the given leaf temperature (μmol m-2 s-1):
    JMax = arrhenius(m.JMaxRef, m.Eₐⱼ, Tₖ, Tᵣₖ, m.Hdⱼ, m.Δₛⱼ, constants.R)
    # Maximum rate of Rubisco activity at the given models temperature (μmol m-2 s-1):
    VcMax = arrhenius(m.VcMaxRef, m.Eₐᵥ, Tₖ, Tᵣₖ, m.Hdᵥ, m.Δₛᵥ, constants.R)
    # Rate of mitochondrial respiration at the given leaf temperature (μmol m-2 s-1):
    Rd = arrhenius(m.RdRef, m.Eₐᵣ, Tₖ, Tᵣₖ, constants.R)
    # Rd is also described as the CO2 release in the light by processes other than the PCO
    # cycle, and termed "day" respiration, or "light respiration" (Harley et al., 1986).

    # Actual electron transport rate (considering intercepted PAR and leaf temperature):
    J = get_J(status.aPPFD, JMax, m.α, m.θ) # in μmol m-2 s-1
    # RuBP regeneration
    Vⱼ = J / 4

    # Stomatal conductance (mol[CO₂] m-2 s-1), dispatched on type of first argument (gs_closure):
    st_closure = gs_closure(models.stomatal_conductance, models, status, meteo, extra)

    Cᵢⱼ = get_Cᵢⱼ(Vⱼ, Γˢ, status.Cₛ, Rd, models.stomatal_conductance.g0, st_closure)

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

    Cᵢᵥ = get_Cᵢᵥ(VcMax, Γˢ, status.Cₛ, Rd, models.stomatal_conductance.g0, st_closure, Km)

    # Rubisco-carboxylation-limited rate of CO₂ assimilation (RuBP activity-limited):
    if Cᵢᵥ <= 0.0 || Cᵢᵥ > status.Cₛ
        Wᵥ = 0.0
    else
        Wᵥ = VcMax * (Cᵢᵥ - Γˢ) / (Cᵢᵥ + Km)
    end

    # Net assimilation (μmol m-2 s-1)
    status.A = min(Wᵥ, Wⱼ, 3 * m.TPURef) - Rd

    # Stomatal conductance (mol[CO₂] m-2 s-1)
    PlantSimEngine.run!(models.stomatal_conductance, models, status, st_closure, extra)

    # Intercellular CO₂ concentration (Cᵢ, μmol mol)
    status.Cᵢ = min(status.Cₛ, status.Cₛ - status.A / status.Gₛ)
    nothing
end


"""
Rate of electron transport J (``μmol\\ m^{-2}\\ s^{-1}``), computed using the smaller root
of the quadratic equation (eq. 4 from Medlyn et al., 2002):

    θ * J² - (α * aPPFD + JMax) * J + α * aPPFD * JMax

NB: we use the smaller root because considering the range of values for θ and α (quite stable),
and aPPFD and JMax, the function always tends to JMax with high aPPFD with the smaller root (behavior we
are searching), and the opposite with the larger root.

# Returns

A tuple with (A, Gₛ, Cᵢ):

- A: carbon assimilation (μmol m-2 s-1)
- Gₛ: stomatal conductance (mol m-2 s-1)
- Cᵢ: intercellular CO₂ concentration (ppm)
# Arguments

- `aPPFD`: absorbed photon irradiance (``μmol_{quanta}\\ m^{-2}\\ s^{-1}``)
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
Fvcb{Float64}(25.0, 200.0, 250.0, 0.6, 9999.0, 46390.0, 210.0, 29680.0, 200000.0, 631.88, 58550.0, 200000.0, 629.26, 0.425, 0.7)

julia> PlantBiophysics.get_J(1500, A.JMaxRef, A.α, A.θ)
216.5715752671342
```
"""
function get_J(aPPFD, JMax, α, θ)
    (α * aPPFD + JMax - sqrt((α * aPPFD + JMax)^2 - 4 * α * θ * aPPFD * JMax)) / (2 * θ)
end

"""
Analytic resolution of Cᵢ when the rate of electron transport is limiting (``μmol\\ mol^{-1}``)

# Arguments

- `Vⱼ`: RuBP regeneration (J/4.0, ``μmol\\ m^{-2}\\ s^{-1}``)
- `Γˢ`: CO2 compensation point ``Γ^⋆`` (``μmol\\ mol^{-1}``)
- `Cₛ`: Air CO₂ concentration at the leaf surface (``μmol\\ mol^{-1}``)
- `Rd`: day respiration (``μmol\\ m^{-2}\\ s^{-1}``)
- `g0`: residual stomatal conductance (``μmol\\ m^{-2}\\ s^{-1}``)
- `st_closure`: stomatal conductance term computed from a given implementation of a Gs model,
e.g. [`Medlyn`](@ref).


# References

Duursma, R. A., et B. E. Medlyn. 2012. « MAESPA: a model to study interactions between water
limitation, environmental drivers and vegetation function at tree and stand levels, with an
example application to [CO2] × drought interactions ». Geoscientific Model Development 5
(4): 919‑40. https://doi.org/10.5194/gmd-5-919-2012.

Wang and Leuning, 1998
"""
function get_Cᵢⱼ(Vⱼ, Γˢ, Cₛ, Rd, g0, st_closure)
    a = g0 + st_closure * (Vⱼ - Rd)
    b = (1.0 - Cₛ * st_closure) * (Vⱼ - Rd) + g0 * (2.0 * Γˢ - Cₛ) -
        st_closure * (Vⱼ * Γˢ + 2.0 * Γˢ * Rd)
    c = -(1.0 - Cₛ * st_closure) * Γˢ * (Vⱼ + 2.0 * Rd) -
        g0 * 2.0 * Γˢ * Cₛ

    return positive_root(a, b, c)
end

"""
Analytic resolution of Cᵢ when the RuBisCo activity is limiting (``μmol\\ mol^{-1}``)

# Arguments

- `VcMAX`: maximum rate of RuBisCo activity(``μmol\\ m^{-2}\\ s^{-1}``)
- `Γˢ`: CO2 compensation point ``Γ^⋆`` (``μmol\\ mol^{-1}``)
- `Cₛ`: Air CO₂ concentration at the leaf surface (``μmol\\ mol^{-1}``)
- `Rd`: day respiration (``μmol\\ m^{-2}\\ s^{-1}``)
- `g0`: residual stomatal conductance (``μmol\\ m^{-2}\\ s^{-1}``)
- `st_closure`: stomatal conductance term computed from a given implementation of a Gs model,
e.g. [`Medlyn`](@ref).
- `Km`: effective Michaelis–Menten coefficient for CO2 (``μ mol\\ mol^{-1}``)
"""
function get_Cᵢᵥ(VcMAX, Γˢ, Cₛ, Rd, g0, st_closure, Km)
    a = g0 + st_closure * (VcMAX - Rd)
    b = (1.0 - Cₛ * st_closure) * (VcMAX - Rd) + g0 * (Km - Cₛ) - st_closure * (VcMAX * Γˢ + Km * Rd)
    c = -(1.0 - Cₛ * st_closure) * (VcMAX * Γˢ + Km * Rd) - g0 * Km * Cₛ

    return positive_root(a, b, c)
end

"""
Maximum value between two roots of a quadratic equation.
"""
function max_root(a, b, c)
    Δ = b^2.0 - 4.0 * a * c
    x1 = (-b + sqrt(Δ)) / (2.0 * a)
    x2 = (-b - sqrt(Δ)) / (2.0 * a)
    return max(x1, x2)
end


"""
Positive root of a quadratic equation, but returns 0 if Δ is negative.
Careful, this is not right mathematically, but biologically OK because used in the
computation of Cᵢ (gives A = 0 in this case).
"""
function positive_root(a, b, c)
    Δ = b^2.0 - 4.0 * a * c
    return Δ >= 0.0 ? (-b + sqrt(Δ)) / (2.0 * a) : 0.0
end

"""
Negative root of a quadratic equation, but returns 0 if Δ is negative.
Careful, this is not right mathematically, but biologically OK because used in the
computation of Cᵢ (gives A = 0 in this case).
"""
function negative_root(a, b, c)
    Δ = b^2.0 - 4.0 * a * c
    return Δ >= 0.0 ? (-b - sqrt(Δ)) / (2.0 * a) : 0.0
end
