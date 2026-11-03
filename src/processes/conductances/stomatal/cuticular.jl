"""
    CuticularConductance(stomata=Medlyn(g0=0.02, g1=5.5); gcw=0.005, co2_ratio=20)

Add a parallel cuticular pathway to an interchangeable stomatal-conductance
model. `gcw` is the cuticular water conductance (mol H₂O m⁻² s⁻¹), and
`gcw / co2_ratio` is its CO₂ conductance. Both use the same reference leaf
surface as the stomatal model. The defaults are a hypothesis, not a universal
measured cuticular conductance.

The wrapped model's intercept and floor continue to describe **stomata only**.
In particular, a historical fit whose intercept already included the cuticle
must be refitted before adding this pathway. Outputs are stomatal CO₂
conductance `Gₛ` and total epidermal water conductance `Gₗw`.
The Márquez photosynthesis structs consume the parallel CO₂ pathway;
the legacy analytical `Fvcb` retains its original stomatal-only CO₂ equation.

For Lamour's total-water intercept `g0w`, the corresponding stomatal CO₂
intercept is `(g0w-gcw)/constants.Gsc_to_Gsw`. The diffusivity ratio is read
from the simulation constants, rather than hardcoded to the paper's 1.6.

Márquez et al. (2021), https://doi.org/10.1038/s41477-021-00861-w.
"""
struct CuticularConductance{M,T} <: AbstractStomatal_ConductanceModel
    stomata::M
    gcw::T
    co2_ratio::T
end

function CuticularConductance(stomata::AbstractStomatal_ConductanceModel=Medlyn(g0=0.02, g1=5.5);
    gcw=0.005, co2_ratio=20)
    g, ratio = promote(float(gcw), float(co2_ratio))
    isfinite(g) && g >= zero(g) || throw(ArgumentError("gcw must be finite and nonnegative"))
    isfinite(ratio) && ratio > zero(ratio) || throw(ArgumentError("co2_ratio must be finite and positive"))
    CuticularConductance(stomata, g, ratio)
end

Base.eltype(m::CuticularConductance) = promote_type(eltype(m.stomata), typeof(m.gcw))
PlantSimEngine.inputs_(m::CuticularConductance) = merge(PlantSimEngine.inputs_(m.stomata),
    (A=PlantSimEngine.Required(Real),))
PlantSimEngine.outputs_(::CuticularConductance) = (Gₛ=-Inf, Gₗw=-Inf)
PlantSimEngine.environment_inputs_(m::CuticularConductance) = PlantSimEngine.environment_inputs_(m.stomata)
PlantSimEngine.variable_contracts_(m::CuticularConductance) = merge(
    PlantSimEngine.variable_contracts_(m.stomata),
    (Gₛ=STOMATAL_CO2_CONDUCTANCE_CONTRACT, Gₗw=LEAF_WATER_CONDUCTANCE_CONTRACT))
PlantSimEngine.timestep_hint(::Type{<:CuticularConductance}) = (
    required=(Dates.Minute(1), Dates.Hour(6)), preferred=Dates.Hour(1))
PlantSimEngine.output_policy(::Type{<:CuticularConductance}) = (
    Gₛ=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()),
    Gₗw=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()))

gs_coupling(m::CuticularConductance, status, environment, constants=nothing, context=nothing) =
    gs_coupling(m.stomata, status, environment, constants, context)
gs_closure(m::CuticularConductance, status, environment, constants=nothing, context=nothing) =
    gs_closure(m.stomata, status, environment, constants, context)

# New transport models require an explicit cuticular provider. A bare
# stomatal model must not silently disable the cuticle; gcw=0 is explicit.
cuticular_water_conductance(::AbstractStomatal_ConductanceModel) =
    throw(ArgumentError("Use CuticularConductance(stomata) with the transport photosynthesis models; use gcw=0 explicitly for the zero-cuticle limit."))
cuticular_water_conductance(m::CuticularConductance) = m.gcw
cuticular_co2_conductance(::AbstractStomatal_ConductanceModel) =
    throw(ArgumentError("A cuticular CO₂ pathway must be declared by the conductance provider."))
cuticular_co2_conductance(m::CuticularConductance) = m.gcw / m.co2_ratio

function PlantSimEngine.run!(m::CuticularConductance, status, environment,
    constants=PlantMeteo.Constants(), context=nothing)
    # Retain the sampled weather: a custom affine stomatal law may depend on
    # humidity or another environmental field even when its slope was already
    # calculated by the photosynthesis solver.
    environment isa Number && throw(ArgumentError(
        "CuticularConductance requires the sampled environment, not a precomputed scalar slope."))
    coupling = gs_coupling(m.stomata, status, environment, constants, context)
    slope = coupling.slope
    status.Gₛ = max(coupling.gs_min, coupling.g0 + slope * status.A)
    status.Gₗw = gsc_to_gsw(status.Gₛ, constants.Gsc_to_Gsw) + m.gcw
    return nothing
end
