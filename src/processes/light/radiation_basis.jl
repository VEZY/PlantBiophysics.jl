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

const LEAF_PAR_PHOTON_FLUX_CONTRACT = PlantSimEngine.VariableContract(
    unit=:micromol_photon,
    basis=:leaf_area,
    temporal=:second,
    aggregation=:rate,
    extent=:intensive,
)

const LEAF_IRRADIANCE_CONTRACT = PlantSimEngine.VariableContract(
    unit=:joule,
    basis=:leaf_area,
    temporal=:second,
    aggregation=:rate,
    extent=:intensive,
)

const RADIATIVE_MESH_PAR_PHOTON_FLUX_CONTRACT = PlantSimEngine.VariableContract(
    unit=:micromol_photon,
    basis=:radiative_mesh_area,
    temporal=:second,
    aggregation=:rate,
    extent=:intensive,
)

const RADIATIVE_MESH_IRRADIANCE_CONTRACT = PlantSimEngine.VariableContract(
    unit=:joule,
    basis=:radiative_mesh_area,
    temporal=:second,
    aggregation=:rate,
    extent=:intensive,
)

const RADIATIVE_MESH_AREA_CONTRACT = PlantSimEngine.VariableContract(
    unit=:square_metre_radiative,
    basis=:organ,
    temporal=nothing,
    aggregation=:total,
    extent=:extensive,
)

const BOTANICAL_LEAF_AREA_CONTRACT = PlantSimEngine.VariableContract(
    unit=:square_metre_leaf,
    basis=:organ,
    temporal=nothing,
    aggregation=:total,
    extent=:extensive,
)

@process "radiation_basis_conversion" """
Explicit conversion of radiation to the botanical leaf-area basis.

Use [`GroundToMeanLeafPPFD`](@ref) or
[`GroundToMeanLeafShortwave`](@ref) between a Beer-Lambert canopy model and a
leaf-scale physiology model. The conversion divides the ground-based flux by a
finite, strictly positive leaf area index (`LAI`).

Use [`RadiativeMeshToLeafPPFD`](@ref) or
[`RadiativeMeshToLeafShortwave`](@ref) for an organ flux normalized by its
radiative mesh area. Those conversions require both radiative and botanical
areas and preserve the absorbed quantity.
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

function _finite_positive_area(name::Symbol, area, model)
    (area isa Real && isfinite(area) && area > 0) || throw(
        DomainError(
            area,
            "$(nameof(typeof(model))) requires finite $(name) > 0; got $(repr(area))",
        ),
    )
    return area
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


"""
    RadiativeMeshToLeafPPFD()

Convert an organ PPFD normalized by its radiative mesh area to the botanical
leaf-area basis used by photosynthesis:

```math
aPPFD_{leaf} = aPPFD_{radiative} * A_{radiative} / A_{botanical}.
```

The conversion preserves absorbed photons. Both areas must be finite and
strictly positive. The raw PPFD must be finite and non-negative.
"""
struct RadiativeMeshToLeafPPFD <: AbstractRadiation_Basis_ConversionModel end

PlantSimEngine.inputs_(::RadiativeMeshToLeafPPFD) = (
    aPPFD_radiative=PlantSimEngine.Required(Real),
    radiative_mesh_area=PlantSimEngine.Required(Real),
    botanical_leaf_area=PlantSimEngine.Required(Real),
)

PlantSimEngine.outputs_(::RadiativeMeshToLeafPPFD) = (aPPFD_leaf_mean=-Inf,)

PlantSimEngine.variable_contracts_(::RadiativeMeshToLeafPPFD) = (
    aPPFD_radiative=RADIATIVE_MESH_PAR_PHOTON_FLUX_CONTRACT,
    radiative_mesh_area=RADIATIVE_MESH_AREA_CONTRACT,
    botanical_leaf_area=BOTANICAL_LEAF_AREA_CONTRACT,
    aPPFD_leaf_mean=LEAF_PAR_PHOTON_FLUX_CONTRACT,
)

function PlantSimEngine.run!(
    model::RadiativeMeshToLeafPPFD,
    status,
    environment,
    constants,
    context=nothing,
)
    radiation = _finite_nonnegative_radiation(
        :aPPFD_radiative,
        status.aPPFD_radiative,
        model,
    )
    radiative_area = _finite_positive_area(
        :radiative_mesh_area,
        status.radiative_mesh_area,
        model,
    )
    botanical_area = _finite_positive_area(
        :botanical_leaf_area,
        status.botanical_leaf_area,
        model,
    )
    status.aPPFD_leaf_mean = radiation * radiative_area / botanical_area
    return nothing
end


"""
    RadiativeMeshToLeafShortwave()

Convert an organ shortwave irradiance normalized by its radiative mesh area to
the botanical leaf-area basis used by energy balance. The conversion preserves
absorbed energy:

```math
Ra_SW_f_{leaf} = Ra_SW_f_{radiative} * A_{radiative} / A_{botanical}.
```

Both areas must be finite and strictly positive. The raw irradiance must be
finite and non-negative.
"""
struct RadiativeMeshToLeafShortwave <: AbstractRadiation_Basis_ConversionModel end

PlantSimEngine.inputs_(::RadiativeMeshToLeafShortwave) = (
    Ra_SW_f_radiative=PlantSimEngine.Required(Real),
    radiative_mesh_area=PlantSimEngine.Required(Real),
    botanical_leaf_area=PlantSimEngine.Required(Real),
)

PlantSimEngine.outputs_(::RadiativeMeshToLeafShortwave) =
    (Ra_SW_f_leaf_mean=-Inf,)

PlantSimEngine.variable_contracts_(::RadiativeMeshToLeafShortwave) = (
    Ra_SW_f_radiative=RADIATIVE_MESH_IRRADIANCE_CONTRACT,
    radiative_mesh_area=RADIATIVE_MESH_AREA_CONTRACT,
    botanical_leaf_area=BOTANICAL_LEAF_AREA_CONTRACT,
    Ra_SW_f_leaf_mean=LEAF_IRRADIANCE_CONTRACT,
)

function PlantSimEngine.run!(
    model::RadiativeMeshToLeafShortwave,
    status,
    environment,
    constants,
    context=nothing,
)
    radiation = _finite_nonnegative_radiation(
        :Ra_SW_f_radiative,
        status.Ra_SW_f_radiative,
        model,
    )
    radiative_area = _finite_positive_area(
        :radiative_mesh_area,
        status.radiative_mesh_area,
        model,
    )
    botanical_area = _finite_positive_area(
        :botanical_leaf_area,
        status.botanical_leaf_area,
        model,
    )
    status.Ra_SW_f_leaf_mean = radiation * radiative_area / botanical_area
    return nothing
end
