# Include inside PlantBiophysics after the conductance and energy-balance models.
PlantSimEngine.@process "plant_hydraulics" verbose=false
PlantSimEngine.@process "leaf_hydraulics" verbose=false

const WATER_POTENTIAL_CONTRACT = PlantSimEngine.VariableContract(
    unit=:megapascal, basis=nothing, temporal=:instantaneous,
    aggregation=:state, extent=:intensive,
)
const LEAF_WATER_FLUX_CONTRACT = PlantSimEngine.VariableContract(
    unit=:mole_h2o, basis=:surface_area, temporal=:second,
    aggregation=:rate, extent=:intensive,
)
const ORGAN_WATER_FLUX_CONTRACT = PlantSimEngine.VariableContract(
    unit=:mole_h2o, basis=:organ, temporal=:second,
    aggregation=:rate, extent=:extensive,
)
const PLANT_WATER_FLUX_CONTRACT = PlantSimEngine.VariableContract(
    unit=:mole_h2o, basis=:plant, temporal=:second,
    aggregation=:rate, extent=:extensive,
)

"""
    HydraulicLeafEnergy(; water_density=1000.0, gravity=9.80665)

Couple a leaf's water potential to its energy/gas-exchange model. Inputs are
`Ψ_base_leaf` (MPa), `leaf_height` above the root base (m), and `leaf_area`
(m² of the reference surface used by the energy model). The leaf potential is
`Ψₗ = Ψ_base_leaf - water_density*gravity*leaf_height/1e6`.

The declared `energy_balance` hard call normally selects [`Monteith`](@ref),
which can call FvCB and [`Tuzet`](@ref). Other energy models must accept the
same sampled weather fields and enforce their own convergence checks.
It retains the existing accepted-state
writer for every energy and gas-exchange output. This model adds `Ψₗ`,
`E_leaf` (mol H₂O m⁻² s⁻¹) and `E_leaf_total` (mol H₂O s⁻¹). Latent heat is
converted using the local atmosphere's `λ` (J kg⁻¹) and `constants.Mₕ₂ₒ`.
The bridge supplies one consistent sampled leaf atmosphere to its energy
model; set leaf-specific environment bindings on this bridge application.

There is no leaf-specific hydraulic resistance: leaves share one basal
potential and differ only by gravitational head. Negative transpiration
(condensation) is rejected because this model describes daytime root supply.
"""
struct HydraulicLeafEnergy{T} <: AbstractLeaf_HydraulicsModel
    water_density::T
    gravity::T
end

function HydraulicLeafEnergy(; water_density=1000.0, gravity=9.80665)
    density, g = promote(float(water_density), float(gravity))
    isfinite(density) && density > 0 && isfinite(g) && g >= 0 ||
        throw(ArgumentError("Positive water density and nonnegative gravity required"))
    return HydraulicLeafEnergy(density, g)
end

Base.eltype(::HydraulicLeafEnergy{T}) where {T} = T
PlantSimEngine.inputs_(::HydraulicLeafEnergy) = (
    Ψ_base_leaf=PlantSimEngine.Required(Real),
    leaf_area=PlantSimEngine.Required(Real),
    leaf_height=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(m::HydraulicLeafEnergy) = (
    Ψₗ=zero(m.gravity), E_leaf=zero(m.gravity), E_leaf_total=zero(m.gravity),
)
# The bridge supplies a consistent leaf atmosphere to the whole nested solve.
# Its binding may be spatial/leaf-specific; the energy trial must use that
# same atmosphere as the latent-heat-to-water conversion.
PlantSimEngine.environment_inputs_(::HydraulicLeafEnergy) = merge(
    PlantSimEngine.environment_inputs_(Monteith()), (λ=2.45e6,),
)
PlantSimEngine.variable_contracts_(::HydraulicLeafEnergy) = (
    Ψ_base_leaf=WATER_POTENTIAL_CONTRACT,
    Ψₗ=WATER_POTENTIAL_CONTRACT,
    leaf_area=PlantSimEngine.VariableContract(unit=:square_metre, basis=:organ,
        temporal=:instantaneous, aggregation=:state, extent=:extensive),
    leaf_height=PlantSimEngine.VariableContract(unit=:metre, basis=nothing,
        temporal=:instantaneous, aggregation=:state, extent=:intensive),
    E_leaf=LEAF_WATER_FLUX_CONTRACT,
    E_leaf_total=ORGAN_WATER_FLUX_CONTRACT,
)
PlantSimEngine.dep(::HydraulicLeafEnergy) = (
    energy_balance=PlantSimEngine.Call(
        PlantSimEngine.One(within=PlantSimEngine.Self(), process=:energy_balance)),
)
PlantSimEngine.output_policy(::Type{<:HydraulicLeafEnergy}) = (
    Ψₗ=PlantSimEngine.Aggregate(PlantMeteo.MeanWeighted()),
    E_leaf=PlantSimEngine.Aggregate(PlantMeteo.MeanWeighted()),
    E_leaf_total=PlantSimEngine.Aggregate(PlantMeteo.MeanWeighted()),
)

# A different energy model is responsible for its own convergence guarantee.
# Monteith exposes the iteration count and energy fluxes needed for this check.
_check_hydraulic_energy(::AbstractEnergy_BalanceModel, status) = nothing
function _check_hydraulic_energy(model::Monteith, status)
    all(isfinite, (status.Rn, status.H, status.λE, status.Tₗ)) &&
        0 <= status.iter < model.maxiter || throw(ErrorException(
            "Leaf energy balance did not converge during the hydraulic solve"))
    scale = max(one(status.Rn), abs(status.Rn), abs(status.H), abs(status.λE))
    tolerance = max(oftype(scale, 1e-6), 32eps(one(scale))*scale)
    abs(status.Rn-status.H-status.λE) <= tolerance || throw(ErrorException(
        "Leaf energy fluxes do not close during the hydraulic solve"))
    return nothing
end

function PlantSimEngine.run!(m::HydraulicLeafEnergy, status, environment,
    constants=PlantMeteo.Constants(), context=nothing)
    all(isfinite, (status.Ψ_base_leaf, status.leaf_area, status.leaf_height,
        environment.λ, constants.Mₕ₂ₒ)) && status.leaf_area > 0 &&
        status.leaf_height >= 0 && environment.λ > 0 && constants.Mₕ₂ₒ > 0 ||
        throw(ArgumentError("Finite potential, positive reference area and latent heat, and nonnegative height required"))
    status.Ψₗ = status.Ψ_base_leaf -
        m.water_density * m.gravity * status.leaf_height / oftype(m.gravity, 1e6)

    # Publication permission propagates down the PSE hard-call stack: under a
    # plant hydraulic trial this request cannot publish; the accepted call can.
    # Forward the bridge's atmosphere so latent heat and λ share one forcing.
    energy = only(PlantSimEngine.run_call!(context, :energy_balance;
        sampled_environment=environment, publish=true))
    _check_hydraulic_energy(PlantSimEngine.call_model(context, :energy_balance), energy.status)
    E = energy.status.λE / (environment.λ * constants.Mₕ₂ₒ)
    isfinite(E) && E >= zero(E) || throw(DomainError(E,
        "Steady daytime hydraulics does not support condensation or nonfinite water flux"))
    status.E_leaf = E
    status.E_leaf_total = status.leaf_area * E
    return nothing
end

"""
    SteadyPlantHydraulics(; K_plant, minimum_potential=-10,
        potential_tolerance=..., flux_tolerance=..., maxiter=80)

Find a stationary basal xylem potential satisfying
`K_plant*(Ψ_soil-Ψ_base) = sum(E_leaf_total)` for this plant's leaves.
`K_plant` is whole-plant hydraulic conductance in mol H₂O s⁻¹ MPa⁻¹;
`Ψ_soil` is a required status input in MPa. The conductance is constant: this
model has no water storage, capacitance, embolism, or soil-water dynamics.

Each bisection trial sets the declared distributed `Ψ_base_leaf` output, then
calls descendant `HydraulicLeafEnergy` applications without publishing.
After convergence, one accepted call publishes the leaf hydraulic, energy
and gas-exchange outputs. Bind `Ψ_base_leaf` using `OutputTo` to exactly the
same leaves selected by the declared `leaves` hard call.

The minimum potential is a numerical bracket, not a clipping threshold.
Unbracketed supply–demand balance, condensation and nonconvergence are errors.
Tolerances are absolute MPa and mol H₂O s⁻¹; their defaults accommodate
Float32 and Float64 potential resolution. The flux tolerance stays absolute;
if Float32 cannot represent a sufficiently small hydraulic head, the solver
fails rather than weakening water conservation. All coupled components run
at the same timestep.
"""
struct SteadyPlantHydraulics{T} <: AbstractPlant_HydraulicsModel
    K_plant::T
    minimum_potential::T
    potential_tolerance::T
    flux_tolerance::T
    maxiter::Int
end

function SteadyPlantHydraulics(; K_plant,
    minimum_potential=oftype(float(K_plant), -10),
    potential_tolerance=oftype(float(K_plant),
        max(1e-8, 16eps(one(float(K_plant)))*max(1,abs(minimum_potential)))),
    flux_tolerance=oftype(float(K_plant), 1e-9),
    maxiter=80)
    values = promote(float(K_plant), float(minimum_potential),
        float(potential_tolerance), float(flux_tolerance))
    all(isfinite, values) && values[1] > 0 && values[3] > 0 && values[4] > 0 ||
        throw(ArgumentError("Finite positive K_plant and positive numerical tolerances required"))
    maxiter isa Integer && !(maxiter isa Bool) && maxiter > 0 ||
        throw(ArgumentError("maxiter must be a positive integer"))
    return SteadyPlantHydraulics(values..., Int(maxiter))
end

Base.eltype(::SteadyPlantHydraulics{T}) where {T} = T
PlantSimEngine.inputs_(::SteadyPlantHydraulics) = (Ψ_soil=PlantSimEngine.Required(Real),)
PlantSimEngine.outputs_(m::SteadyPlantHydraulics) = (
    Ψ_base=zero(m.K_plant),
    Ψ_base_leaf=PlantSimEngine.Distributed(PlantSimEngine.Default(zero(m.K_plant))),
    E_plant=zero(m.K_plant), hydraulic_supply=zero(m.K_plant),
    hydraulic_residual=zero(m.K_plant), hydraulic_iterations=0,
)
PlantSimEngine.variable_contracts_(::SteadyPlantHydraulics) = (
    Ψ_soil=WATER_POTENTIAL_CONTRACT,
    Ψ_base=WATER_POTENTIAL_CONTRACT,
    Ψ_base_leaf=WATER_POTENTIAL_CONTRACT,
    E_plant=PLANT_WATER_FLUX_CONTRACT,
    hydraulic_supply=PLANT_WATER_FLUX_CONTRACT,
    hydraulic_residual=PLANT_WATER_FLUX_CONTRACT,
)
PlantSimEngine.dep(::SteadyPlantHydraulics) = (
    leaves=PlantSimEngine.Call(PlantSimEngine.Many(scale=:Leaf,
        within=PlantSimEngine.Subtree(), process=:leaf_hydraulics)),
)
PlantSimEngine.output_policy(::Type{<:SteadyPlantHydraulics}) = (
    Ψ_base=PlantSimEngine.Aggregate(PlantMeteo.MeanWeighted()),
    E_plant=PlantSimEngine.Aggregate(PlantMeteo.MeanWeighted()),
    hydraulic_supply=PlantSimEngine.Aggregate(PlantMeteo.MeanWeighted()),
    hydraulic_residual=PlantSimEngine.Aggregate(PlantMeteo.MeanWeighted()),
)

# Private numerical kernel, also tested against closed-form water balances.
# The public model obtains demand from real PSE leaf applications, not a user
# callback or a reconstructed fresh scene for each trial.
function _solve_steady_hydraulics(model::SteadyPlantHydraulics, Ψ_soil, demand)
    isfinite(Ψ_soil) && model.minimum_potential < Ψ_soil ||
        throw(ArgumentError("Ψ_soil must be finite and above minimum_potential"))
    function trial(Ψ)
        E = demand(Ψ)
        isfinite(E) && E >= zero(E) || throw(DomainError(E,
            "Steady daytime hydraulics requires nonnegative finite demand"))
        supply = model.K_plant * (Ψ_soil-Ψ)
        return (Ψ_base=Ψ, E_plant=E, supply=supply, residual=supply-E)
    end
    lo, hi = promote(model.minimum_potential, Ψ_soil)
    lower, upper = trial(lo), trial(hi)
    lower.residual >= 0 && upper.residual <= 0 ||
        throw(DomainError((lo, hi), "Hydraulic supply-demand root is not bracketed"))
    iszero(upper.residual) && return merge(upper, (iterations=0,))
    iszero(lower.residual) && return merge(lower, (iterations=0,))
    for iteration in 1:model.maxiter
        mid = lo + (hi-lo)/2
        state = trial(mid)
        if iszero(state.residual) ||
            (abs(state.residual) <= model.flux_tolerance &&
                hi-lo <= model.potential_tolerance)
            return merge(state, (iterations=iteration,))
        end
        (mid == lo || mid == hi) && throw(ErrorException(
            "Hydraulic bisection stagnated at machine precision; review tolerances or continuity"))
        if state.residual > 0
            lo, lower = mid, state
        else
            hi, upper = mid, state
        end
    end
    throw(ErrorException("Hydraulic supply-demand balance did not converge"))
end

function PlantSimEngine.run!(model::SteadyPlantHydraulics, status, environment,
    constants=PlantMeteo.Constants(), context=nothing)
    leaves = PlantSimEngine.call_targets(context, :leaves)
    destinations = PlantSimEngine.output_targets(context, (:Ψ_base_leaf,))
    destination_ids = PlantSimEngine.object_ids(destinations)
    length(leaves) == length(destination_ids) &&
        Set(target.object_id for target in leaves) == Set(destination_ids) ||
        throw(ArgumentError("Hydraulic output destinations must be exactly the called leaves"))

    function demand(Ψ)
        fill!(destinations.columns.Ψ_base_leaf, Ψ)
        PlantSimEngine.run_call!(context, :leaves; publish=false)
        return sum((leaf.status.E_leaf_total for leaf in leaves); init=zero(model.K_plant))
    end
    balance = _solve_steady_hydraulics(model, status.Ψ_soil, demand)

    # Recompute and publish only this accepted water-potential state.
    fill!(destinations.columns.Ψ_base_leaf, balance.Ψ_base)
    accepted = PlantSimEngine.run_call!(context, :leaves; publish=true)
    status.Ψ_base = balance.Ψ_base
    status.E_plant = sum((leaf.status.E_leaf_total for leaf in accepted); init=zero(model.K_plant))
    status.hydraulic_supply = model.K_plant * (status.Ψ_soil-status.Ψ_base)
    status.hydraulic_residual = status.hydraulic_supply-status.E_plant
    status.hydraulic_iterations = balance.iterations
    abs(status.hydraulic_residual) <= model.flux_tolerance || throw(ErrorException(
        "Accepted hydraulic state does not match the converged water balance"))
    return nothing
end
