const MarquezFitModel = Union{FvcbMarquez,FvcbRectangularMarquez}
const JohnsonFitModel = Union{JohnsonBerry,JohnsonBerryThermal}

# Reuse the forward biochemical equations. The optimizer works on bounded
# parameters, but its finite-difference probes can be just outside a bound.
_fit_transport_model(m::FvcbMarquez, base, capacity) = FvcbMarquez(base, m.gm)
_fit_transport_model(m::FvcbRectangularMarquez, base, capacity) = FvcbRectangularMarquez(base, m.gm)
_fit_transport_model(m::JohnsonBerry, base, capacity) =
    JohnsonBerry(base, promote(m.gm, capacity, m.nL_ref, m.nC_ref)...)
_fit_transport_model(m::JohnsonBerryThermal, base, capacity) =
    JohnsonBerryThermal(base, promote(m.gm, capacity, m.nL_ref, m.nC_ref, m.Eₐb, m.Hd_eff, m.Δₛ_eff)...)

function _transport_fit_column(df, name)
    hasproperty(df, name) || throw(ArgumentError("Transport fit requires column $name"))
    column = getproperty(df, name)
    column isa AbstractVector || throw(ArgumentError("Column $name must be a vector"))
    all(x -> x isa Real && isfinite(x), column) ||
        throw(ArgumentError("Column $name must contain only finite numeric observations"))
    return Float64.(column)
end

function _transport_fit_bound(name, bound, strictly_positive)
    (bound isa Tuple || bound isa AbstractVector) && length(bound) == 2 &&
        all(x -> x isa Real, bound) ||
        throw(ArgumentError("$name bounds must be a pair of real numbers"))
    lo, hi = Float64.(bound)
    isfinite(lo) && lo >= 0 && lo <= hi && (!strictly_positive || lo > 0) ||
        throw(ArgumentError("Invalid bounds for $name: $bound (electron capacity requires a positive lower bound)"))
    return lo, hi
end

function _fit_transport(m, df, capacity_name, capacity, capacity_bound;
    Tᵣ, VcMaxRef, RdRef, TPURef=nothing,
    VcMaxRef_bound=(0.0, Inf), RdRef_bound=(0.0, Inf), TPURef_bound=(0.0, Inf),
    maxiter=350)
    m.gm == Inf || throw(ArgumentError("Transport fit uses Cᵢ = C꜀ and requires gm=Inf"))
    maxiter isa Integer && !(maxiter isa Bool) && maxiter > 0 ||
        throw(ArgumentError("maxiter must be a positive integer"))

    temperature, light, ci, observed = map(k -> _transport_fit_column(df, k), (:Tₗ, :aPPFD, :Cᵢ, :A))
    n = length(observed)
    n > 0 && length(temperature) == length(light) == length(ci) == n ||
        throw(ArgumentError("Supply nonempty columns Tₗ, aPPFD, Cᵢ and A of equal length"))
    constants = PlantMeteo.Constants()
    all(>(constants.K₀), temperature) && all(>=(0), light) && all(>=(0), ci) ||
        throw(ArgumentError("Require physical Tₗ in °C and nonnegative aPPFD and Cᵢ"))
    Tr = isnothing(Tᵣ) ? Statistics.mean(temperature) : Tᵣ
    Tr isa Real && isfinite(Tr) && Tr > constants.K₀ ||
        throw(ArgumentError("Tᵣ must be a finite temperature above absolute zero in °C"))

    keys = (:VcMaxRef, capacity_name, :RdRef, :TPURef)
    bounds = map(_transport_fit_bound, keys,
        (VcMaxRef_bound, capacity_bound, RdRef_bound, TPURef_bound), (false, true, false, false))
    guesses = (VcMaxRef, capacity, RdRef, isnothing(TPURef) ? m.base.TPURef : TPURef)
    initial = zeros(4)
    free = Int[]
    for i in eachindex(keys)
        lo, hi = bounds[i]
        if lo == hi
            initial[i] = lo
        else
            v = guesses[i]
            v isa Real && isfinite(v) && lo <= v <= hi ||
                throw(ArgumentError("$(keys[i]) must start within its bounds"))
            initial[i] = v
            (i != 4 || !isnothing(TPURef)) && push!(free, i)
        end
    end
    isempty(free) && throw(ArgumentError("At least one parameter must be free"))
    n > length(free) || throw(ArgumentError("Need more observations than free parameters"))

    base = NamedTuple{fieldnames(typeof(m.base))}(Tuple(getfield(m.base, k) for k in fieldnames(typeof(m.base))))
    function predict(x, p)
        values = convert.(eltype(p), initial)
        values[free] = p
        vc, electron, rd, tpu = values
        jmax = m isa MarquezFitModel ? electron : m.base.JMaxRef
        updated = Fvcb(; merge(base, (; Tᵣ=Tr, VcMaxRef=vc, JMaxRef=jmax, RdRef=rd, TPURef=tpu))...)
        model = _fit_transport_model(m, updated, electron)
        return [_transport_assimilation(model, light[i], ci[i],
            _transport_biochemistry(model, temperature[i], constants)) for i in x]
    end

    lower = [bounds[i][1] for i in free]
    upper = [bounds[i][2] for i in free]
    # A second, lower-capacity start can expose limitations hidden at the first start.
    alternative = clamp.(initial[free] .* 0.55, lower, upper)
    best = nothing
    best_sse = Inf
    for start in (initial[free], alternative)
        result = LsqFit.curve_fit(predict, collect(1:n), observed, start;
            lower, upper, maxIter=maxiter)
        sse = sum(abs2, result.resid)
        if result.converged && all(isfinite, result.param) && sse < best_sse
            best, best_sse = result, sse
        end
    end
    isnothing(best) && throw(ArgumentError("Transport fit did not converge; review the data, starting values and bounds"))
    jacobian = best.jacobian .* reshape(max.(abs.(best.param), 1.0), 1, :)
    LinearAlgebra.rank(jacobian; rtol=sqrt(eps(Float64))) == length(free) ||
        throw(ArgumentError("Response curves do not constrain every free parameter at the solution. Sample the relevant limiting regimes or fix unsupported parameters with equal bounds."))
    initial[free] = best.param
    return NamedTuple{(keys..., :Tᵣ)}((initial..., Float64(Tr)))
end

"""
    Evaluation.fit(ModelType, df; base=Fvcb(), Tᵣ=base.Tᵣ, kwargs...)
    Evaluation.fit(model, df; Tᵣ=model.base.Tᵣ, kwargs...)

Fit the biochemical component of `FvcbMarquez`, `FvcbRectangularMarquez`,
`JohnsonBerry` or `JohnsonBerryThermal` to gas-exchange observations.
Supply columns `A` (µmol CO₂ m⁻² s⁻¹), `Tₗ` (°C), `aPPFD` (absorbed
µmol photons m⁻² s⁻¹) and `Cᵢ` (µmol mol⁻¹), as returned by `read_licor6800`.
Use quality-controlled observations from a common leaf or parameter group.

The fit treats the supplied `Cᵢ` as chloroplastic CO₂ (`gm=Inf`); it does not
fit stomata, cuticular conductance or chamber corrections. Other biochemical
and thermal parameters stay fixed at the supplied template settings.
Type-based calls default to the base model reference temperature and starting values
`VcMaxRef=60`, `RdRef=0.8` and `JMaxRef=150` (Márquez) or
`Cb6fMaxRef=90` (Johnson–Berry). Instance calls start from the template. Use `Tᵣ=nothing` explicitly to use
mean observed leaf temperature; changing the reference also reanchors the
existing temperature-dependent Rubisco constants.

Supply `TPURef` to estimate TPU only when high-CO₂ observations support it.
Otherwise TPU stays fixed at the template's value. Set per-parameter
`_bound` pairs (e.g. `RdRef_bound=(0.8, 0.8)` to fix Rd).
Bounds default to nonnegative, except electron capacity which is strictly
positive (lower bound 0.1). `maxiter` controls iterations per starting point.

Return a named tuple with `VcMaxRef`, the model's capacity (`JMaxRef` or
`Cb6fMaxRef`), `RdRef`, `TPURef` and `Tᵣ`. The fit throws if no start
converges or the final sensitivity matrix is numerically rank deficient.
"""
function PlantSimEngine.Evaluation.fit(type::Union{Type{FvcbMarquez},Type{FvcbRectangularMarquez}},
    df; base=Fvcb(), Tᵣ=base.Tᵣ, VcMaxRef=60.0, RdRef=0.8, JMaxRef=150.0, kwargs...)
    return PlantSimEngine.Evaluation.fit(type(; base), df; Tᵣ, VcMaxRef, RdRef, JMaxRef, kwargs...)
end

function PlantSimEngine.Evaluation.fit(type::Union{Type{JohnsonBerry},Type{JohnsonBerryThermal}},
    df; base=Fvcb(), Tᵣ=base.Tᵣ, VcMaxRef=60.0, RdRef=0.8, Cb6fMaxRef=90.0, kwargs...)
    return PlantSimEngine.Evaluation.fit(type(; base), df;
        Tᵣ, VcMaxRef, RdRef, Cb6fMaxRef, kwargs...)
end

function PlantSimEngine.Evaluation.fit(m::MarquezFitModel, df;
    Tᵣ=m.base.Tᵣ, VcMaxRef=m.base.VcMaxRef, RdRef=m.base.RdRef, JMaxRef=m.base.JMaxRef,
    JMaxRef_bound=(0.1, Inf), kwargs...)
    return _fit_transport(m, df, :JMaxRef, JMaxRef, JMaxRef_bound; Tᵣ, VcMaxRef, RdRef, kwargs...)
end

function PlantSimEngine.Evaluation.fit(m::JohnsonFitModel, df;
    Tᵣ=m.base.Tᵣ, VcMaxRef=m.base.VcMaxRef, RdRef=m.base.RdRef, Cb6fMaxRef=m.Cb6fMaxRef,
    Cb6fMaxRef_bound=(0.1, Inf), kwargs...)
    return _fit_transport(m, df, :Cb6fMaxRef, Cb6fMaxRef, Cb6fMaxRef_bound; Tᵣ, VcMaxRef, RdRef, kwargs...)
end
