"""
    FvcbMechanisms(; base=Fvcb(), electron_transport=:nonrectangular,
        gas_transport=:fick, temperature_response=:standard, g0w=0.02,
        g1=5.5, gcw=0.0, gsw_min=0.0016, gm=Inf,
        Cb6fMaxRef=base.JMaxRef, nL_ref=0.75, nC_ref=1.0,
        Eₐb=43540.0, Hd_eff=152040.0, Δₛ_eff=495.0)

Coupled FvCB, USO conductance, and alternative electron/CO₂ transport hypotheses.
`electron_transport` selects `:nonrectangular` (FvCB), `:rectangular` (the
θ→0 Johnson–Berry approximation), or `:cytochrome` (Johnson–Berry Cyt b₆f,
with CO₂-dependent ATP coupling). `gas_transport` selects `:fick` or
`:marquez` (stomatal and cuticular diffusion with the ternary correction).
`temperature_response=:cytochrome` is available only with `:cytochrome`: the
activation is assigned to Cyt b₆f capacity and thermal deactivation to the
ATP coupling efficiencies. These are separate hypotheses, not equivalent
ways to parameterize the same temperature response.

`g0w`, `gcw`, and `gsw_min` are **water** conductances in mol m⁻² s⁻¹;
`g1` has units kPa¹ᐟ² when `Dₗ` is in kPa; `gm` is mesophyll CO₂
conductance in mol m⁻² s⁻¹.
The default `gm=Inf` explicitly assumes Cc=Ci because mesophyll
conductance has not been measured. `Cb6fMaxRef` is a separate capacity and
must be calibrated for a full Cyt b₆f test. `base.α` is the effective PSI
quantum yield in that mode. The cuticular CO₂/H₂O conductance ratio is 1/20.

Outputs are net assimilation `A` (μmol CO₂ m⁻² s⁻¹), intercellular CO₂ `Cᵢ`
(μmol mol⁻¹), stomatal CO₂ conductance `Gₛ` (mol m⁻² s⁻¹), and *total leaf*
water conductance `Gₗw` (mol m⁻² s⁻¹). [`Monteith`](@ref) uses `Gₗw` when
available, so cuticular transpiration enters the energy balance.

# Example

```julia
using PlantBiophysics, PlantMeteo, PlantSimEngine, Dates
gas = FvcbMechanisms(base=Fvcb(α=0.39),
    electron_transport=:cytochrome, temperature_response=:cytochrome,
    gas_transport=:marquez, Cb6fMaxRef=90.0, gcw=0.005)
scene = CompositeModel(Monteith(), gas;
    status=Status(aPPFD=600.0, Ra_SW_f=110.0, sky_fraction=2.0, d=0.03),
    environment=Atmosphere(T=25.0, Wind=1.0, P=101.3, Rh=0.6,
        Cₐ=400.0, duration=Hour(1)))
run!(scene)
leaf = only(model_objects(scene)).status
(leaf.A, leaf.Gₗw)
```

# References

- Johnson & Berry (2021), Photosynthesis Research 148:101–136,
  https://doi.org/10.1007/s11120-021-00840-4
- Johnson, Field & Berry (2021), Oecologia 197:841–866,
  https://doi.org/10.1007/s00442-021-05062-y
- Márquez et al. (2021), Nature Plants 7:317–326,
  https://doi.org/10.1038/s41477-021-00861-w
- Lamour et al. (2022), New Phytologist 233:592–598,
  https://doi.org/10.1111/nph.17762
"""
struct FvcbMechanisms{F,T} <: AbstractPhotosynthesisModel
    base::F
    electron_transport::Symbol
    gas_transport::Symbol
    temperature_response::Symbol
    g0w::T
    g1::T
    gcw::T
    gsw_min::T
    gm::T
    Cb6fMaxRef::T
    nL_ref::T
    nC_ref::T
    Eₐb::T
    Hd_eff::T
    Δₛ_eff::T
end

function FvcbMechanisms(; base=Fvcb(), electron_transport=:nonrectangular,
    gas_transport=:fick, temperature_response=:standard, g0w=0.02,
    g1=5.5, gcw=0.0, gsw_min=0.0016, gm=Inf,
    Cb6fMaxRef=base.JMaxRef, nL_ref=0.75, nC_ref=1.0,
    Eₐb=43540.0, Hd_eff=152040.0, Δₛ_eff=495.0)
    electron_transport in (:nonrectangular, :rectangular, :cytochrome) ||
        throw(ArgumentError("unknown electron transport formulation"))
    gas_transport in (:fick, :marquez) ||
        throw(ArgumentError("unknown gas transport formulation"))
    temperature_response in (:standard, :cytochrome) ||
        throw(ArgumentError("unknown temperature response formulation"))
    temperature_response === :cytochrome && electron_transport !== :cytochrome &&
        throw(ArgumentError("cytochrome temperature response requires cytochrome electron transport"))
    values = promote(g0w, g1, gcw, gsw_min, gm, Cb6fMaxRef, nL_ref, nC_ref,
        Eₐb, Hd_eff, Δₛ_eff)
    values[1] >= 0 && values[3] >= 0 && values[4] > 0 &&
        values[3] <= values[1] && values[6] > 0 &&
        0 < values[7] <= 1 && 0 < values[8] <= 1 && values[5] > 0 ||
        throw(ArgumentError("conductances and Cyt b₆f parameters must be physically positive, with gcw ≤ g0w"))
    FvcbMechanisms(base, electron_transport, gas_transport, temperature_response, values...)
end

Base.eltype(x::FvcbMechanisms) = typeof(x.g0w)

PlantSimEngine.inputs_(::FvcbMechanisms) = (
    aPPFD=PlantSimEngine.Required(Real), Tₗ=PlantSimEngine.Required(Real),
    Cₛ=PlantSimEngine.Required(Real), Dₗ=PlantSimEngine.Required(Real),
)
PlantSimEngine.variable_contracts_(::FvcbMechanisms) =
    (aPPFD=LEAF_PAR_PHOTON_FLUX_CONTRACT,)
PlantSimEngine.environment_inputs_(::FvcbMechanisms) = (T=25.0, Rh=0.5, P=101.3)
PlantSimEngine.outputs_(::FvcbMechanisms) =
    (A=-Inf, Cᵢ=-Inf, Gₛ=-Inf, Gₗw=-Inf)
PlantSimEngine.timestep_hint(::Type{<:FvcbMechanisms}) = (
    required=(Dates.Minute(1), Dates.Hour(6)), preferred=Dates.Hour(1))
PlantSimEngine.output_policy(::Type{<:FvcbMechanisms}) = (
    A=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()),
    Cᵢ=PlantSimEngine.Integrate(PlantMeteo.MeanReducer()),
    Gₛ=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()),
    Gₗw=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()),
)

function PlantSimEngine.run!(m::FvcbMechanisms, status, environment,
    constants=PlantMeteo.Constants(), context=nothing)
    # The single root solve keeps the carbon and water pathways coupled. Each
    # trial computes its own stomatal aperture, intercellular CO₂, chloroplast
    # CO₂, electron transport, and biochemical demand.
    f = m.base
    Tₖ = status.Tₗ - constants.K₀
    Tᵣₖ = f.Tᵣ - constants.K₀
    Γˢ = Γ_star(Tₖ, Tᵣₖ, constants.R)
    Km = get_km(Tₖ, Tᵣₖ, f.O₂, constants.R)
    VcMax = arrhenius(f.VcMaxRef, f.Eₐᵥ, Tₖ, Tᵣₖ, f.Hdᵥ, f.Δₛᵥ, constants.R)
    Rd = arrhenius(f.RdRef, f.Eₐᵣ, Tₖ, Tᵣₖ, constants.R)

    if m.temperature_response === :cytochrome
        capacity = arrhenius(m.Cb6fMaxRef, m.Eₐb, Tₖ, Tᵣₖ, constants.R)
        efficiency = arrhenius(1.0, 0.0, Tₖ, Tᵣₖ, m.Hd_eff, m.Δₛ_eff, constants.R)
        nL = m.nL_ref * efficiency
        nC = m.nC_ref * efficiency
    else
        reference_capacity = m.electron_transport === :cytochrome ?
            m.Cb6fMaxRef : f.JMaxRef
        capacity = arrhenius(reference_capacity, f.Eₐⱼ, Tₖ, Tᵣₖ,
            f.Hdⱼ, f.Δₛⱼ, constants.R)
        nL, nC = m.nL_ref, m.nC_ref
    end

    # Mole fractions at the inner and outer leaf surface. Dₗ is used by USO;
    # the local vapour gradient is calculated from temperature and humidity.
    wi = PlantMeteo.e_sat(status.Tₗ) / environment.P
    ws = PlantMeteo.e_sat(environment.T) * environment.Rh / environment.P
    k = (wi - ws) / (2 - wi - ws)
    cuticular_co2 = m.gas_transport === :marquez ? m.gcw / 20 : zero(m.gcw)
    closure = 1 + m.g1 / sqrt(max(status.Dₗ, 1e-9))

    # A lies between respiration-only exchange and gross biochemical capacity.
    lo = -Rd
    # Rubisco demand cannot exceed VcMax, regardless of the electron branch.
    hi = min(VcMax, 3 * f.TPURef)
    A = lo
    Ci = status.Cₛ
    gsw = m.gsw_min
    for _ in 1:70
        A = (lo + hi) / 2
        total_water = m.g0w + 1.6 * closure * A / status.Cₛ
        gsw = max(m.gsw_min, total_water - m.gcw)
        gsc = gsw / 1.6
        if m.gas_transport === :marquez
            numerator = status.Cₛ * (gsc + cuticular_co2 - gsw * k) - A
            denominator = gsc + cuticular_co2 + gsw * k
            Ci = numerator / denominator
        else
            Ci = status.Cₛ - A / gsc
        end
        Cc = max(0.0, Ci - A / m.gm)

        if m.electron_transport === :cytochrome
            η = 1 - nL / nC + (3 * Cc + 7 * Γˢ) / ((4 * Cc + 8 * Γˢ) * nC)
            J = capacity * status.aPPFD /
                (capacity / f.α + status.aPPFD) / η
        elseif m.electron_transport === :rectangular
            photons = f.α * status.aPPFD
            J = capacity * photons / (capacity + photons)
        else
            J = get_J(status.aPPFD, capacity, f.α, f.θ)
        end
        Wc = VcMax * (Cc - Γˢ) / (Cc + Km)
        Wj = (J / 4) * (Cc - Γˢ) / (Cc + 2 * Γˢ)
        demand = min(Wc, Wj, 3 * f.TPURef) - Rd
        if demand > A
            lo = A
        else
            hi = A
        end
        hi - lo <= 1e-8 && break
    end
    status.A = A
    status.Cᵢ = Ci
    status.Gₛ = gsw / 1.6
    status.Gₗw = gsw + (m.gas_transport === :marquez ? m.gcw : zero(m.gcw))
    nothing
end
