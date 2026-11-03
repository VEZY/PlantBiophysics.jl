"""
Photosynthesis models coupled to stomatal and cuticular CO₂ diffusion, with
the ternary correction of Márquez et al. (2021) and Lamour et al. (2022).

Each concrete struct chooses one electron-transport hypothesis. The stomatal
law remains a separate process: use `CuticularConductance(Medlyn(...))` or
wrap Tuzet/prescribed conductance instead. `gm=Inf` assumes chloroplast and
intercellular CO₂ are equal; finite `gm` is a CO₂ conductance in mol m⁻² s⁻¹.
"""
abstract type AbstractTransportPhotosynthesis <: AbstractPhotosynthesisModel end

PlantSimEngine.process(::AbstractTransportPhotosynthesis) = :photosynthesis

"""
    FvcbMarquez(; base=Fvcb(), gm=Inf)

FvCB with the nonrectangular electron-transport hyperbola and corrected
stomatal/cuticular transport. `base` supplies the biochemical parameters.
Pair with [`CuticularConductance`](@ref), whose default includes the cuticle.
Use an explicit `gcw=0` to test the zero-cuticle limit.
"""
struct FvcbMarquez{F,T} <: AbstractTransportPhotosynthesis
    base::F
    gm::T
end

"""
    FvcbRectangularMarquez(; base=Fvcb(), gm=Inf)

FvCB with a rectangular electron-transport hyperbola and Márquez transport.
This tests the curvature assumption separately from the Cyt b₆f formulation.
"""
struct FvcbRectangularMarquez{F,T} <: AbstractTransportPhotosynthesis
    base::F
    gm::T
end

"""
    JohnsonBerry(; base=Fvcb(), gm=Inf, Cb6fMaxRef=base.JMaxRef,
        nL_ref=0.75, nC_ref=1.0)

Johnson–Berry Cyt b₆f electron transport and CO₂-dependent ATP coupling,
with the standard peaked temperature response applied to Cyt b₆f capacity.
`base.α` is the effective PSI quantum yield, and `Cb6fMaxRef` is a separate
capacity that must be calibrated rather than identified with Jmax by fiat.
The default merely supplies an initial numerical value.

Johnson & Berry (2021), https://doi.org/10.1007/s11120-021-00840-4.
"""
struct JohnsonBerry{F,T} <: AbstractTransportPhotosynthesis
    base::F
    gm::T
    Cb6fMaxRef::T
    nL_ref::T
    nC_ref::T
end

"""
    JohnsonBerryThermal(; base=Fvcb(), gm=Inf, Cb6fMaxRef=base.JMaxRef,
        nL_ref=0.75, nC_ref=1.0, Eₐb=43540.0,
        Hd_eff=152040.0, Δₛ_eff=495.0)

Johnson–Berry electron transport with Arrhenius activation of Cyt b₆f
capacity and peaked thermal deactivation assigned to ATP coupling efficiency.
It agrees with [`JohnsonBerry`](@ref) at `base.Tᵣ` for identical parameters,
but makes a different physiological assumption away from that temperature.

Johnson, Field & Berry (2021), https://doi.org/10.1007/s00442-021-05062-y.
"""
struct JohnsonBerryThermal{F,T} <: AbstractTransportPhotosynthesis
    base::F
    gm::T
    Cb6fMaxRef::T
    nL_ref::T
    nC_ref::T
    Eₐb::T
    Hd_eff::T
    Δₛ_eff::T
end

function _check_transport_parameters(base, gm)
    gm > zero(gm) && !isnan(gm) || throw(ArgumentError("gm must be positive or Inf"))
    all(isfinite, (base.Tᵣ, base.VcMaxRef, base.JMaxRef, base.RdRef, base.TPURef,
        base.Eₐᵣ, base.O₂, base.Eₐⱼ, base.Hdⱼ, base.Δₛⱼ, base.Eₐᵥ,
        base.Hdᵥ, base.Δₛᵥ, base.α, base.θ)) ||
        throw(ArgumentError("Biochemical parameters must be finite"))
    base.Tᵣ > -273.15 && base.VcMaxRef >= 0 && base.JMaxRef > 0 &&
        base.RdRef >= 0 && base.TPURef >= 0 && base.α > 0 &&
        0 <= base.θ <= 1 || throw(ArgumentError("Invalid biochemical capacity or light response"))
    return nothing
end

function FvcbMarquez(; base=Fvcb(), gm=oftype(base.VcMaxRef, Inf))
    _check_transport_parameters(base, gm)
    FvcbMarquez(base, float(gm))
end
function FvcbRectangularMarquez(; base=Fvcb(), gm=oftype(base.VcMaxRef, Inf))
    _check_transport_parameters(base, gm)
    FvcbRectangularMarquez(base, float(gm))
end

function _check_cytochrome(capacity, nL, nC)
    all(isfinite, (capacity, nL, nC)) && capacity > 0 &&
        0 < nL <= 1 && 0 < nC <= 1 && nC + oftype(nC, 0.75) > nL ||
        throw(ArgumentError("Positive Cyt b₆f capacity and positive ATP-coupling efficiency required"))
    return nothing
end

function JohnsonBerry(; base=Fvcb(), gm=oftype(base.VcMaxRef, Inf),
    Cb6fMaxRef=base.JMaxRef, nL_ref=0.75, nC_ref=1.0)
    values = promote(float(gm), Cb6fMaxRef, nL_ref, nC_ref)
    _check_transport_parameters(base, values[1])
    _check_cytochrome(values[2], values[3], values[4])
    JohnsonBerry(base, values...)
end

function JohnsonBerryThermal(; base=Fvcb(), gm=oftype(base.VcMaxRef, Inf),
    Cb6fMaxRef=base.JMaxRef, nL_ref=0.75, nC_ref=1.0,
    Eₐb=43540.0, Hd_eff=152040.0, Δₛ_eff=495.0)
    values = promote(float(gm), Cb6fMaxRef, nL_ref, nC_ref, Eₐb, Hd_eff, Δₛ_eff)
    _check_transport_parameters(base, values[1])
    _check_cytochrome(values[2], values[3], values[4])
    all(isfinite, values[5:7]) && values[5] >= 0 && values[6] > 0 && values[7] >= 0 ||
        throw(ArgumentError("Invalid cytochrome thermal-response parameters"))
    JohnsonBerryThermal(base, values...)
end

Base.eltype(m::AbstractTransportPhotosynthesis) = promote_type(eltype(m.base), typeof(m.gm))
PlantSimEngine.inputs_(::AbstractTransportPhotosynthesis) = (
    aPPFD=PlantSimEngine.Required(Real), Tₗ=PlantSimEngine.Required(Real),
    Cₛ=PlantSimEngine.Required(Real))
PlantSimEngine.outputs_(::AbstractTransportPhotosynthesis) =
    (A=-Inf, Cᵢ=-Inf, C꜀=-Inf, Gₛ=-Inf, Gₗw=-Inf)
PlantSimEngine.environment_inputs_(::AbstractTransportPhotosynthesis) = (T=25.0, Rh=0.5, P=101.3)
PlantSimEngine.variable_contracts_(::AbstractTransportPhotosynthesis) = (
    aPPFD=LEAF_PAR_PHOTON_FLUX_CONTRACT,
    Gₛ=STOMATAL_CO2_CONDUCTANCE_CONTRACT, Gₗw=LEAF_WATER_CONDUCTANCE_CONTRACT)
PlantSimEngine.dep(::AbstractTransportPhotosynthesis) = (
    stomatal_conductance=PlantSimEngine.Call(
        PlantSimEngine.One(within=PlantSimEngine.Self(), process=:stomatal_conductance)),)
PlantSimEngine.timestep_hint(::Type{<:AbstractTransportPhotosynthesis}) = (
    required=(Dates.Minute(1), Dates.Hour(6)), preferred=Dates.Hour(1))
PlantSimEngine.output_policy(::Type{<:AbstractTransportPhotosynthesis}) = (
    A=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()),
    Cᵢ=PlantSimEngine.Integrate(PlantMeteo.MeanReducer()),
    C꜀=PlantSimEngine.Integrate(PlantMeteo.MeanReducer()),
    Gₛ=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()),
    Gₗw=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()))

function _transport_biochemistry(m::AbstractTransportPhotosynthesis, Tleaf,
    constants=PlantMeteo.Constants())
    f = m.base
    Tₖ, Tᵣₖ = Tleaf - constants.K₀, f.Tᵣ - constants.K₀
    isfinite(Tleaf) && Tₖ > 0 || throw(ArgumentError("A physical leaf temperature is required"))
    capacity, nL, nC = _transport_capacity(m, Tₖ, Tᵣₖ, constants)
    return (Γ=Γ_star(Tₖ, Tᵣₖ, constants.R),
        Km=get_km(Tₖ, Tᵣₖ, f.O₂, constants.R),
        VcMax=arrhenius(f.VcMaxRef, f.Eₐᵥ, Tₖ, Tᵣₖ, f.Hdᵥ, f.Δₛᵥ, constants.R),
        Rd=arrhenius(f.RdRef, f.Eₐᵣ, Tₖ, Tᵣₖ, constants.R),
        capacity=capacity, nL=nL, nC=nC)
end

function _transport_capacity(m::Union{FvcbMarquez,FvcbRectangularMarquez}, Tₖ, Tᵣₖ, c)
    f = m.base
    (arrhenius(f.JMaxRef, f.Eₐⱼ, Tₖ, Tᵣₖ, f.Hdⱼ, f.Δₛⱼ, c.R), zero(Tₖ), zero(Tₖ))
end
function _transport_capacity(m::JohnsonBerry, Tₖ, Tᵣₖ, c)
    f = m.base
    (arrhenius(m.Cb6fMaxRef, f.Eₐⱼ, Tₖ, Tᵣₖ, f.Hdⱼ, f.Δₛⱼ, c.R), m.nL_ref, m.nC_ref)
end
function _transport_capacity(m::JohnsonBerryThermal, Tₖ, Tᵣₖ, c)
    efficiency = arrhenius(one(Tₖ), zero(Tₖ), Tₖ, Tᵣₖ, m.Hd_eff, m.Δₛ_eff, c.R)
    (arrhenius(m.Cb6fMaxRef, m.Eₐb, Tₖ, Tᵣₖ, c.R),
        m.nL_ref * efficiency, m.nC_ref * efficiency)
end

_transport_electrons(m::FvcbMarquez, light, Cc, b) = get_J(light, b.capacity, m.base.α, m.base.θ)
function _transport_electrons(m::FvcbRectangularMarquez, light, Cc, b)
    photons = m.base.α * light
    b.capacity * photons / (b.capacity + photons)
end
function _transport_electrons(m::Union{JohnsonBerry,JohnsonBerryThermal}, light, Cc, b)
    η = 1 - b.nL / b.nC + (3Cc + 7b.Γ) / ((4Cc + 8b.Γ) * b.nC)
    isfinite(η) && η > zero(η) || throw(DomainError(η, "Nonpositive ATP-coupling efficiency"))
    photons = m.base.α * light
    return b.capacity * photons / (b.capacity + photons) / η
end

"""Net biochemical assimilation at chloroplast CO₂, without stomatal coupling.

This private kernel also permits conditional evaluation with measured Ci when
`gm=Inf`; it does not estimate Ci, leaf temperature or stomatal conductance.
"""
function _transport_assimilation(m::AbstractTransportPhotosynthesis, light, Cc, b)
    isfinite(light) && light >= 0 && isfinite(Cc) && Cc >= 0 ||
        throw(ArgumentError("Nonnegative finite irradiance and chloroplast CO₂ required"))
    J = _transport_electrons(m, light, Cc, b)
    return min(b.VcMax * (Cc - b.Γ) / (Cc + b.Km),
        (J / 4) * (Cc - b.Γ) / (Cc + 2b.Γ), 3m.base.TPURef) - b.Rd
end

# Lamour et al. (2022), equation note, Eq. 13. The ternary transport term uses
# stomatal transpiration Es, not total transpiration: cuticular water loss Ec
# is a separate pathway (Eqs. 6, 7 and 12). Hence gsw*k intentionally excludes
# gcw, while the energy balance receives gsw+gcw.
# Both concentrations are referenced to the leaf surface: external vapour is
# approximated by ambient humidity, as in the conference model. This does not
# solve a separate boundary-layer humidity gradient or amphistomatous anatomy.
function _marquez_ci(A, Cs, gsc, gcw, gcc, water_ratio, k)
    gsw = gsc_to_gsw(gsc, water_ratio)
    denominator = gsc + gcc + gsw * k
    denominator > zero(denominator) ||
        throw(DomainError(denominator, "No positive epidermal CO₂ transport pathway"))
    return (Cs * (gsc + gcc - gsw * k) - A) / denominator
end

function _transport_trial(m, A, Cs, light, coupling, gcw, gcc, water_ratio, k, b)
    gs = max(coupling.gs_min, coupling.g0 + coupling.slope * A)
    Ci = _marquez_ci(A, Cs, gs, gcw, gcc, water_ratio, k)
    Cc = Ci - A / m.gm
    # Negative Cc is allowed only in bracket trials. Extending the biochemical
    # residual constantly below zero avoids poles; accepted roots are checked
    # against the unmodified physical domain below.
    expected = _transport_assimilation(m, light, max(zero(Cc), Cc), b)
    return (residual=expected-A, A=A, Ci=Ci, Cc=Cc, gs=gs,
        Glw=gsc_to_gsw(gs, water_ratio)+gcw, expected=expected)
end

_transport_root_tolerance(A, expected, Rd) =
    64eps(one(A)) * max(one(A), abs(A), abs(expected), abs(Rd))

function _bisect_transport(trial, lo, hi)
    left, right = trial(lo), trial(hi)
    abs(left.residual) <= _transport_root_tolerance(left.A, left.expected, zero(left.A)) && return left
    abs(right.residual) <= _transport_root_tolerance(right.A, right.expected, zero(right.A)) && return right
    signbit(left.residual) != signbit(right.residual) ||
        iszero(left.residual) || iszero(right.residual) ||
        throw(DomainError((lo, hi), "Photosynthesis root is not bracketed"))
    for _ in 1:160
        mid = lo + (hi-lo)/2
        state = trial(mid)
        abs(state.residual) <= _transport_root_tolerance(mid, state.expected, zero(mid)) && return state
        if mid == lo || mid == hi
            break
        end
        if signbit(state.residual) == signbit(left.residual)
            lo, left = mid, state
        else
            hi, right = mid, state
        end
    end
    best = abs(left.residual) < abs(right.residual) ? left : right
    abs(best.residual) <= 4 * _transport_root_tolerance(best.A, best.expected, zero(best.A)) ||
        throw(ErrorException("Photosynthesis root did not converge"))
    return best
end

function _solve_transport(m, Cs, light, coupling, gcw, gcc, water_ratio, k, b)
    T = promote_type(typeof(Cs), typeof(light), typeof(coupling.g0), typeof(b.Rd), eltype(m))
    # Low CO₂ can give net release below -Rd through photorespiration. The old
    # [-Rd, capacity] bracket excluded that valid part of the domain.
    upper = convert(T, min(b.VcMax, 3m.base.TPURef) - b.Rd)
    lower = convert(T, _transport_assimilation(m, light, zero(T), b))
    trial(A) = _transport_trial(m, A, Cs, light, coupling, gcw, gcc, water_ratio, k, b)
    points = T[lower, upper, clamp(zero(T), lower, upper)]
    if coupling.g0 < 0 || coupling.slope < 0
        # Negative fitted intercepts may introduce multiple branches. Retain
        # the highest physical stationary assimilation, like analytical FvCB.
        append!(points, range(lower, upper; length=65))
    end
    !iszero(coupling.slope) && push!(points,
        clamp(convert(T, (coupling.gs_min-coupling.g0)/coupling.slope), lower, upper))
    sort!(unique!(points))
    candidates = Any[]
    previous = trial(first(points))
    abs(previous.residual) <= _transport_root_tolerance(previous.A, previous.expected, b.Rd) && push!(candidates, previous)
    for point in Iterators.drop(points, 1)
        current = trial(point)
        if abs(current.residual) <= _transport_root_tolerance(current.A, current.expected, b.Rd)
            push!(candidates, current)
        elseif signbit(previous.residual) != signbit(current.residual)
            push!(candidates, _bisect_transport(trial, previous.A, current.A))
        end
        previous = current
    end
    filter!(s -> s.Ci >= 0 && s.Cc >= 0 && s.gs >= 0 &&
        abs(s.residual) <= 4 * _transport_root_tolerance(s.A, s.expected, b.Rd), candidates)
    isempty(candidates) && throw(DomainError((Cs, coupling), "No admissible coupled photosynthesis state"))
    return candidates[argmax([s.A for s in candidates])]
end

function PlantSimEngine.run!(m::AbstractTransportPhotosynthesis, status, environment,
    constants=PlantMeteo.Constants(), context=nothing)
    all(isfinite, (status.Cₛ, status.aPPFD, environment.T, environment.Rh, environment.P)) &&
        status.Cₛ >= 0 && status.aPPFD >= 0 && environment.P > 0 && 0 <= environment.Rh <= 1 ||
        throw(ArgumentError("Invalid CO₂, irradiance, pressure or humidity"))
    stomata = PlantSimEngine.call_model(context, :stomatal_conductance)
    coupling = gs_coupling(stomata, status, environment, constants, context)
    all(isfinite, values(coupling)) && coupling.gs_min >= 0 ||
        throw(ArgumentError("Finite affine stomatal coupling and nonnegative floor required"))
    gcw, gcc = cuticular_water_conductance(stomata), cuticular_co2_conductance(stomata)
    wi = PlantMeteo.e_sat(status.Tₗ) / environment.P
    ws = PlantMeteo.e_sat(environment.T) * environment.Rh / environment.P
    0 <= wi < 1 && 0 <= ws < 1 || throw(DomainError((wi, ws), "Invalid vapour mole fractions"))
    k = (wi-ws)/(2-wi-ws)
    b = _transport_biochemistry(m, status.Tₗ, constants)
    state = _solve_transport(m, status.Cₛ, status.aPPFD, coupling,
        gcw, gcc, constants.Gsc_to_Gsw, k, b)
    status.A, status.Cᵢ, status.C꜀ = state.A, state.Ci, state.Cc
    PlantSimEngine.run_call!(context, :stomatal_conductance;
        sampled_environment=environment, publish=false)
    # Parent publishes the accepted conductances from the same carbon solve.
    isapprox(status.Gₛ, state.gs; rtol=128eps(one(state.gs)), atol=0) &&
        isapprox(status.Gₗw, state.Glw; rtol=128eps(one(state.Glw)), atol=0) ||
        throw(ErrorException("Stomatal execution disagrees with gs_coupling"))
    return nothing
end
