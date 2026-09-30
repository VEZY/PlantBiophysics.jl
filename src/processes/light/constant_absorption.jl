"""
    ConstantAbsorption(; α_PAR, α_NIR)
    ConstantAbsorption(α_PAR, α_NIR)

Absorb fixed fractions of the incident PAR and near-infrared (NIR) radiation.
Both fractions must be finite and between 0 and 1. Supply them explicitly for
the surface and light source being simulated; there is no universal leaf value.

The environment supplies `Ri_PAR_f` and `Ri_NIR_f` in W m⁻² of the represented
surface. Outputs use the same area: `Ra_PAR_f`, `Ra_NIR_f`, and their sum
`Ra_SW_f` are in W m⁻²; `aPPFD` is in µmol photons m⁻² s⁻¹. The conversion
from absorbed PAR energy to photons uses `constants.J_to_umol`, which should
match the light spectrum when reproducing chamber measurements.

No `LAI`, geometry, or timestep duration is needed. Absorbed radiation follows
the current incident radiation, while the fractions stay constant. These are
instantaneous fluxes, not energy totals over the timestep. The model can run on
any object whose incoming radiation is expressed per its represented surface
area; it does not convert ground-area fluxes to leaf-area fluxes or calculate
shading. On a leaf it couples directly to [`Fvcb`](@ref) and [`Monteith`](@ref).

# Example

The fractions below are illustrative, not calibrated to a particular leaf.

```julia
using PlantBiophysics, PlantSimEngine, PlantMeteo

scene = CompositeModel(
    ConstantAbsorption(α_PAR=0.8, α_NIR=0.2),
    Monteith(), Fvcb(), Medlyn(0.03, 12.0);
    status=Status(sky_fraction=1.0, d=0.03),
    environment=Atmosphere(
        T=25.0, Wind=1.0, P=101.3, Rh=0.6,
        Ri_PAR_f=300.0, Ri_NIR_f=350.0,
    ),
)
run!(scene)
only(model_objects(scene)).status.A
```
"""
struct ConstantAbsorption{T<:Real} <: AbstractLight_InterceptionModel
    α_PAR::T
    α_NIR::T

    function ConstantAbsorption(α_PAR::Real, α_NIR::Real)
        for (name, fraction) in ((:α_PAR, α_PAR), (:α_NIR, α_NIR))
            (isfinite(fraction) && 0 <= fraction <= 1) || throw(
                DomainError(fraction, "ConstantAbsorption requires finite $name between 0 and 1"),
            )
        end
        fractions = promote(float(α_PAR), float(α_NIR))
        return new{typeof(first(fractions))}(fractions...)
    end
end

ConstantAbsorption(; α_PAR, α_NIR) = ConstantAbsorption(α_PAR, α_NIR)

PlantSimEngine.inputs_(::ConstantAbsorption) = NamedTuple()
PlantSimEngine.environment_inputs_(model::ConstantAbsorption) = (
    Ri_PAR_f=zero(model.α_PAR), Ri_NIR_f=zero(model.α_NIR),
)
PlantSimEngine.outputs_(model::ConstantAbsorption) = (
    Ra_PAR_f=zero(model.α_PAR), Ra_NIR_f=zero(model.α_NIR),
    Ra_SW_f=zero(model.α_PAR), aPPFD=zero(model.α_PAR),
)

# As for BeerShortwave, band-specific diagnostics remain uncontracted because
# the current contract vocabulary cannot distinguish PAR from NIR energy.
PlantSimEngine.variable_contracts_(::ConstantAbsorption) = (
    Ra_SW_f=LEAF_IRRADIANCE_CONTRACT,
    aPPFD=LEAF_PAR_PHOTON_FLUX_CONTRACT,
)

PlantSimEngine.Authoring.model_metadata(::ConstantAbsorption) = (
    hypothesis="Fixed PAR and NIR absorption fractions on the incident surface-area basis.",
    reference=nothing,
    maturity=:user_parameterized,
    validation=:analytical_and_coupling_tests,
)
PlantSimEngine.Authoring.parameter_metadata(::ConstantAbsorption) = (
    α_PAR=(description="Fraction of incident PAR absorbed.", unit=:dimensionless,
        domain=(minimum=0, maximum=1)),
    α_NIR=(description="Fraction of incident NIR absorbed.", unit=:dimensionless,
        domain=(minimum=0, maximum=1)),
)

function PlantSimEngine.run!(model::ConstantAbsorption, status, environment, constants, context=nothing)
    par = _finite_nonnegative_radiation(:Ri_PAR_f, environment.Ri_PAR_f, model)
    nir = _finite_nonnegative_radiation(:Ri_NIR_f, environment.Ri_NIR_f, model)
    status.Ra_PAR_f = model.α_PAR * par
    status.Ra_NIR_f = model.α_NIR * nir
    status.Ra_SW_f = status.Ra_PAR_f + status.Ra_NIR_f
    status.aPPFD = status.Ra_PAR_f * constants.J_to_umol
    return nothing
end
