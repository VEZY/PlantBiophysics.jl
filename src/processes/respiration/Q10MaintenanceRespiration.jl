@process "maintenance_respiration" """
Maintenance respiration: respiratory carbon release associated with maintaining
existing living tissue, distinct from the construction cost of new tissue.

The process returns positive release rates for an organ. The scene defines
which organs are represented and how their rates enter a plant carbon budget.
It does not automatically change net leaf photosynthesis.
""" verbose = false

"""
    Q10MaintenanceRespiration(; Q10, Mr, T_ref, P_alive,
        grams_CH2O_per_mol_CO2=30.026)

Dry-biomass maintenance respiration at the current **organ** temperature:

``Rm = B × P_alive × Mr × Q10^((Torgan - T_ref) / 10)``.

All physiological parameters must be supplied:

- `Q10`: multiplier for a 10 °C increase, positive and dimensionless.
- `Mr`: maintenance coefficient at `T_ref`, in g CH₂O-equivalent
  g⁻¹ living dry matter day⁻¹. It applies to the mass after multiplying by
  `P_alive`; do not apply the living fraction a second time inside `Mr`.
- `T_ref`: reference organ temperature in °C.
- `P_alive`: fraction of the supplied structural dry mass to which `Mr`
  applies, from zero to one.

Inputs are `structural_mass_gDM` (g dry matter per organ) and
`organ_temperature_C` (°C). Outputs are positive carbon-release **rates**:
`Rm_gCH2O_per_day_at_T` (g CH₂O-equivalent day⁻¹ per organ) and
`Rm_CO2_umol_s` (µmol CO₂ s⁻¹ per organ). Neither is an interval amount.
One mole of CH₂O-equivalent represents one mole of respiratory CO₂; the
default molar mass is a bookkeeping conversion, not an organ coefficient.

This is a local empirical temperature response. It does not model growth
respiration, acclimation, substrate limitation, nitrogen turnover or tissue
death. Species-specific coefficients, mass allometry and the represented
organ boundary belong to the application. In particular, darkness alone
does not guarantee that measured efflux equals maintenance respiration.

Do not subtract leaflet maintenance again when leaf net assimilation already
includes the FvCB mitochondrial term `Rd`. Adding respiration from nonleaf
organs is a separate, explicit carbon-budget operation.

# Reference

Henson, I. E. (2004). Estimating maintenance respiration of oil palm.
Oil Palm Bulletin 48:1–10. The organ/temperature bookkeeping follows this
framework; no oil-palm tissue coefficient is supplied by this model.
https://opb.mpob.gov.my/estimating-maintenance-respiration-of-oil-palm/
"""
struct Q10MaintenanceRespiration{T} <: AbstractMaintenance_RespirationModel
    Q10::T
    Mr::T
    T_ref::T
    P_alive::T
    grams_CH2O_per_mol_CO2::T
end

function Q10MaintenanceRespiration(; Q10, Mr, T_ref, P_alive,
    grams_CH2O_per_mol_CO2=30.026)
    q, coefficient, reference, alive = promote(float(Q10), float(Mr), float(T_ref), float(P_alive))
    molar_mass = oftype(q, grams_CH2O_per_mol_CO2)
    values = (q, coefficient, reference, alive, molar_mass)
    all(isfinite, values) || throw(ArgumentError("Respiration parameters must be finite"))
    q > zero(q) && coefficient >= zero(coefficient) &&
        reference > oftype(reference, -273.15) &&
        zero(alive) <= alive <= one(alive) && molar_mass > zero(molar_mass) ||
        throw(ArgumentError("Require Q10>0, Mr≥0, T_ref>absolute zero, 0≤P_alive≤1, and positive molar mass"))
    return Q10MaintenanceRespiration(values...)
end

Base.eltype(::Q10MaintenanceRespiration{T}) where {T} = T
PlantSimEngine.inputs_(::Q10MaintenanceRespiration) = (
    structural_mass_gDM=PlantSimEngine.Required(Real),
    organ_temperature_C=PlantSimEngine.Required(Real))
PlantSimEngine.outputs_(m::Q10MaintenanceRespiration) = (
    Rm_gCH2O_per_day_at_T=zero(m.Mr),
    Rm_CO2_umol_s=zero(m.Mr))
PlantSimEngine.environment_inputs_(::Q10MaintenanceRespiration) = NamedTuple()
PlantSimEngine.environment_outputs_(::Q10MaintenanceRespiration) = NamedTuple()
PlantSimEngine.variable_contracts_(::Q10MaintenanceRespiration) = (
    structural_mass_gDM=PlantSimEngine.VariableContract(
        unit=:g_dry_matter, basis=:object, temporal=:instantaneous,
        aggregation=:state, extent=:extensive),
    organ_temperature_C=PlantSimEngine.VariableContract(
        unit=:degree_celsius, basis=:object, temporal=:instantaneous,
        aggregation=:state, extent=:intensive),
    Rm_gCH2O_per_day_at_T=PlantSimEngine.VariableContract(
        unit=:g_ch2o_equivalent, basis=:object, temporal=:day,
        aggregation=:rate, extent=:extensive),
    Rm_CO2_umol_s=PlantSimEngine.VariableContract(
        unit=:micromol_co2, basis=:object, temporal=:second,
        aggregation=:rate, extent=:extensive))

# Rate-to-rate coarsening preserves the physical numerator/time units. An
# interval amount requires a separately declared adapter and integration.
PlantSimEngine.output_policy(::Type{<:Q10MaintenanceRespiration}) = (
    Rm_gCH2O_per_day_at_T=PlantSimEngine.Aggregate(PlantMeteo.MeanWeighted()),
    Rm_CO2_umol_s=PlantSimEngine.Aggregate(PlantMeteo.MeanWeighted()))

PlantSimEngine.Authoring.model_metadata(::Q10MaintenanceRespiration) = (
    hypothesis="Existing living dry biomass supports a maintenance rate with a Q10 response to current organ temperature.",
    reference="Henson (2004), Oil Palm Bulletin 48:1-10; generic biomass/temperature law, with no species coefficients supplied.",
    maturity=:empirical_temperature_response,
    validation="Kernel, unit, numeric-type and compiled-composition tests; biological calibration is application-specific.")

PlantSimEngine.Authoring.parameter_metadata(::Q10MaintenanceRespiration) = (
    Q10=(description="Rate multiplier for a 10 degree Celsius temperature increase.",
        unit=:dimensionless, domain=(minimum=0,)),
    Mr=(description="Maintenance coefficient per living dry mass at the reference temperature.",
        unit=:g_ch2o_equivalent_per_g_living_dry_matter_per_day, domain=(minimum=0,)),
    T_ref=(description="Reference organ temperature for Mr.", unit=:degree_celsius),
    P_alive=(description="Fraction of supplied structural dry mass to which Mr applies.",
        unit=:dimensionless, domain=(minimum=0, maximum=1)),
    grams_CH2O_per_mol_CO2=(description="Molar bookkeeping conversion from carbohydrate-equivalent carbon to respiratory CO2.",
        unit=:g_ch2o_equivalent_per_mol_co2, domain=(minimum=0,)))

function PlantSimEngine.run!(m::Q10MaintenanceRespiration, status, environment,
    constants=PlantMeteo.Constants(), context=nothing)
    mass, temperature = status.structural_mass_gDM, status.organ_temperature_C
    isfinite(mass) && mass >= zero(mass) ||
        throw(ArgumentError("structural_mass_gDM must be finite and nonnegative"))
    isfinite(temperature) && temperature > constants.K₀ ||
        throw(ArgumentError("organ_temperature_C must be finite and above absolute zero"))
    daily_rate = mass * m.P_alive * m.Mr *
        m.Q10^((temperature-m.T_ref) / oftype(m.T_ref, 10))
    isfinite(daily_rate) || throw(DomainError(daily_rate,
        "Q10 respiration overflow: check the organ temperature and parameter validity range"))
    co2_rate = daily_rate / m.grams_CH2O_per_mol_CO2 *
        (oftype(daily_rate, 1_000_000) / oftype(daily_rate, 86400))
    isfinite(co2_rate) || throw(DomainError(co2_rate,
        "Respiratory CO2 conversion overflow: check the rate and molar conversion"))
    status.Rm_gCH2O_per_day_at_T = daily_rate
    status.Rm_CO2_umol_s = co2_rate
    return nothing
end
