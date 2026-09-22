const LEAF_AREA_INDEX_CONTRACT = PlantSimEngine.VariableContract(
    unit=:square_metre_leaf,
    basis=:ground_area,
    temporal=nothing,
    aggregation=:ratio,
    extent=:intensive,
)

const GROUND_PAR_PHOTON_FLUX_CONTRACT = PlantSimEngine.VariableContract(
    unit=:micromol_photon,
    basis=:ground_area,
    temporal=:second,
    aggregation=:rate,
    extent=:intensive,
)

const GROUND_IRRADIANCE_CONTRACT = PlantSimEngine.VariableContract(
    unit=:joule,
    basis=:ground_area,
    temporal=:second,
    aggregation=:rate,
    extent=:intensive,
)

# Radiation producers and leaf physiology use the same represented surface area.
const LEAF_PAR_PHOTON_FLUX_CONTRACT = PlantSimEngine.VariableContract(
    unit=:micromol_photon,
    basis=:surface_area,
    temporal=:second,
    aggregation=:rate,
    extent=:intensive,
)

const LEAF_IRRADIANCE_CONTRACT = PlantSimEngine.VariableContract(
    unit=:joule,
    basis=:surface_area,
    temporal=:second,
    aggregation=:rate,
    extent=:intensive,
)

@process "radiation_basis_conversion" """
Explicit conversion of canopy radiation to the mean leaf surface-area basis.

Use [`GroundToMeanLeafPPFD`](@ref) or
[`GroundToMeanLeafShortwave`](@ref) between a Beer-Lambert canopy model and a
leaf-scale physiology model. The conversion divides the ground-based flux by a
finite, strictly positive leaf area index (`LAI`).

Geometry-resolved light uses the represented mesh surface as the reference
area and couples directly to leaf physiology with the `:surface_area` contract.
""" verbose = false

function _finite_positive_lai(lai, model)
    (lai isa Real && isfinite(lai) && lai > 0) || throw(
        DomainError(
            lai,
            "$(nameof(typeof(model))) requires finite LAI > 0; got $(repr(lai))",
        ),
    )
    return lai
end

"""
    GroundToMeanLeafPPFD()

Convert absorbed photosynthetic photon flux density from
`μmol[photon] m[ground]⁻² s⁻¹` to the canopy mean in
`μmol[photon] m[leaf]⁻² s⁻¹` by dividing `aPPFD_ground` by `LAI`.

The output is named `aPPFD_leaf_mean` so a scenario must explicitly map it to
the `aPPFD` input of a leaf-scale photosynthesis model. `LAI` must be finite
and positive; `aPPFD_ground` must be finite and non-negative.
"""
struct GroundToMeanLeafPPFD <: AbstractRadiation_Basis_ConversionModel end

PlantSimEngine.inputs_(::GroundToMeanLeafPPFD) = (
    LAI=PlantSimEngine.Required(Real),
    aPPFD_ground=PlantSimEngine.Required(Real),
)

PlantSimEngine.outputs_(::GroundToMeanLeafPPFD) = (aPPFD_leaf_mean=-Inf,)

PlantSimEngine.variable_contracts_(::GroundToMeanLeafPPFD) = (
    LAI=LEAF_AREA_INDEX_CONTRACT,
    aPPFD_ground=GROUND_PAR_PHOTON_FLUX_CONTRACT,
    aPPFD_leaf_mean=LEAF_PAR_PHOTON_FLUX_CONTRACT,
)

function PlantSimEngine.run!(
    model::GroundToMeanLeafPPFD,
    status,
    environment,
    constants,
    context=nothing,
)
    lai = _finite_positive_lai(status.LAI, model)
    radiation = _finite_nonnegative_radiation(
        :aPPFD_ground,
        status.aPPFD_ground,
        model,
    )
    status.aPPFD_leaf_mean = radiation / lai
    return nothing
end

"""
    GroundToMeanLeafShortwave()

Convert absorbed shortwave irradiance from `W m[ground]⁻²` to the canopy mean
in `W m[leaf]⁻²` by dividing `Ra_SW_f_ground` by `LAI`.

The output is named `Ra_SW_f_leaf_mean` so a scenario must explicitly map it
to the `Ra_SW_f` input of a leaf-scale energy-balance model. `LAI` must be
finite and positive; `Ra_SW_f_ground` must be finite and non-negative.
"""
struct GroundToMeanLeafShortwave <: AbstractRadiation_Basis_ConversionModel end

PlantSimEngine.inputs_(::GroundToMeanLeafShortwave) = (
    LAI=PlantSimEngine.Required(Real),
    Ra_SW_f_ground=PlantSimEngine.Required(Real),
)

PlantSimEngine.outputs_(::GroundToMeanLeafShortwave) = (Ra_SW_f_leaf_mean=-Inf,)

PlantSimEngine.variable_contracts_(::GroundToMeanLeafShortwave) = (
    LAI=LEAF_AREA_INDEX_CONTRACT,
    Ra_SW_f_ground=GROUND_IRRADIANCE_CONTRACT,
    Ra_SW_f_leaf_mean=LEAF_IRRADIANCE_CONTRACT,
)

function PlantSimEngine.run!(
    model::GroundToMeanLeafShortwave,
    status,
    environment,
    constants,
    context=nothing,
)
    lai = _finite_positive_lai(status.LAI, model)
    radiation = _finite_nonnegative_radiation(
        :Ra_SW_f_ground,
        status.Ra_SW_f_ground,
        model,
    )
    status.Ra_SW_f_leaf_mean = radiation / lai
    return nothing
end

function _finite_nonnegative_radiation(name::Symbol, radiation, model)
    (radiation isa Real && isfinite(radiation) && radiation >= 0) || throw(
        DomainError(
            radiation,
            "$(nameof(typeof(model))) requires finite $(name) >= 0; got $(repr(radiation))",
        ),
    )
    return radiation
end
