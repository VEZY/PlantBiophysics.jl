module FvcbRegressionTests

using Test
using Dates
using PlantBiophysics
using PlantBiophysics.PlantMeteo
using PlantBiophysics.PlantSimEngine
using MonteCarloMeasurements: Particles, StaticParticles

parameterized_fvcb() = Fvcb(VcMaxRef=120.0, JMaxRef=240.0, RdRef=1.2, TPURef=20.0)
configured_medlyn() = Medlyn(1e-6, 5.8, 0.001)

function leaf_state(;
    temperature, ppfd, coupled_energy=false, relative_humidity=0.65,
    leaf_temperature=temperature,
    model=parameterized_fvcb(), stomatal_model=configured_medlyn(),
    initial_A=0.0, leaf_water_potential=-1.0, surface_co2=400.0,
    scalar_type=Float64,
    constants=PlantMeteo.Constants{scalar_type}(),
)
    environment = Atmosphere(
        T=temperature, Wind=0.8, P=101.325, Rh=relative_humidity,
        Cₐ=surface_co2, duration=Hour(1),
    )
    leaf_vpd = PlantMeteo.e_sat(leaf_temperature) -
               PlantMeteo.e_sat(temperature) * relative_humidity
    values = (
        aPPFD=scalar_type(ppfd), Tₗ=scalar_type(leaf_temperature),
        Cₛ=scalar_type(surface_co2), Dₗ=scalar_type(leaf_vpd),
        Ψₗ=scalar_type(leaf_water_potential), d=scalar_type(0.01),
        Ra_SW_f=scalar_type(ppfd / constants.J_to_umol),
        sky_fraction=scalar_type(0.5),
    )
    # Omitting A leaves FvCB's output at its declared uninitialized value.
    isnothing(initial_A) || (values = merge(values, (A=scalar_type(initial_A),)))
    status = Status(; values...)
    models = coupled_energy ? (Monteith(aₛᵥ=2), model, stomatal_model) :
        (model, stomatal_model)
    type_promotion = scalar_type === Float64 ? nothing : Dict(Float64 => scalar_type)
    scene = CompositeModel(models...; status, environment, type_promotion)
    simulation = PlantSimEngine.run!(scene; steps=1, outputs=:none, constants)
    return final_state(simulation), scene
end

function expected_respiration(temperature; model=parameterized_fvcb())
    constants = PlantMeteo.Constants()
    return PlantBiophysics.arrhenius(
        model.RdRef, model.Eₐᵣ,
        temperature - constants.K₀, model.Tᵣ - constants.K₀, constants.R,
    )
end

# The reference solves the physiological equations in Ci with bisection. It
# neither calls the production Ci/root helpers nor duplicates their algebraic
# branch selection. The already independently tested temperature functions
# supply the declared biochemical parameters.
function reference_parameters(model, temperature, ppfd)
    constants = PlantMeteo.Constants()
    Tₖ = Float64(temperature) - constants.K₀
    Tᵣₖ = Float64(model.Tᵣ) - constants.K₀
    Γ = PlantBiophysics.Γ_star(Tₖ, Tᵣₖ, constants.R)
    Km = PlantBiophysics.get_km(Tₖ, Tᵣₖ, model.O₂, constants.R)
    VcMax = PlantBiophysics.arrhenius(model.VcMaxRef, model.Eₐᵥ,
        Tₖ, Tᵣₖ, model.Hdᵥ, model.Δₛᵥ, constants.R)
    JMax = PlantBiophysics.arrhenius(model.JMaxRef, model.Eₐⱼ,
        Tₖ, Tᵣₖ, model.Hdⱼ, model.Δₛⱼ, constants.R)
    Rd = PlantBiophysics.arrhenius(model.RdRef, model.Eₐᵣ, Tₖ, Tᵣₖ, constants.R)
    photons = Float64(model.α) * Float64(ppfd)
    # The smaller root lies in [0, min(α*PPFD, JMax)]. Bisection avoids using
    # the production rationalized quadratic or subtracting near-equal roots.
    lower, upper = 0.0, min(photons, JMax)
    for _ in 1:100
        J = (lower + upper) / 2
        residual = model.θ * J^2 - (photons + JMax) * J + photons * JMax
        if residual > 0
            lower = J
        else
            upper = J
        end
    end
    return (; Γ, Km, VcMax, JMax, Rd, Vj=(lower + upper) / 8,
        TPU=Float64(model.TPURef))
end

reference_A(p, Ci) = min(
    p.VcMax * (Ci - p.Γ) / (Ci + p.Km),
    p.Vj * (Ci - p.Γ) / (Ci + 2 * p.Γ),
    3 * p.TPU,
) - p.Rd

function reference_gs(model::Medlyn, A, Cs, Dl, Ψₗ)
    return max(model.gs_min,
        model.g0 + (1 + model.g1 / sqrt(max(1e-9, Dl))) * A / Cs)
end

function reference_gs(model::Tuzet, A, Cs, Dl, Ψₗ)
    water_response = (1 + exp(model.sf * model.Ψᵥ)) /
                     (1 + exp(model.sf * (model.Ψᵥ - Ψₗ)))
    return max(model.gs_min, model.g0 + model.g1 * water_response * A / (Cs - model.Γ))
end

reference_gs(model::ConstantGs, A, Cs, Dl, Ψₗ) = model.Gₛ
reference_floor(model::Union{Medlyn,Tuzet}) = model.gs_min
reference_floor(model::ConstantGs) = model.Gₛ

function bisection_reference(model, stomatal_model, temperature, ppfd, Cs, Dl, Ψₗ)
    p = reference_parameters(model, temperature, ppfd)
    residual(Ci) = begin
        A = reference_A(p, Ci)
        A - reference_gs(stomatal_model, A, Cs, Dl, Ψₗ) * (Cs - Ci)
    end
    lower = 0.0
    upper = Float64(Cs) + p.Rd / reference_floor(stomatal_model) + 1.0
    @assert residual(lower) <= 0 <= residual(upper)
    for _ in 1:100
        Ci = (lower + upper) / 2
        if residual(Ci) > 0
            upper = Ci
        else
            lower = Ci
        end
    end
    Ci = (lower + upper) / 2
    A = reference_A(p, Ci)
    return (; A, Gₛ=reference_gs(stomatal_model, A, Cs, Dl, Ψₗ), Cᵢ=Ci)
end

function check_equilibrium(state, model, stomatal_model, ppfd;
    leaf_water_potential=-1.0, atol=1e-8, rtol=2e-8,
)
    reference = bisection_reference(model, stomatal_model, state.Tₗ, ppfd,
        state.Cₛ, state.Dₗ, leaf_water_potential)
    p = reference_parameters(model, state.Tₗ, ppfd)
    @test state.A ≈ reference.A atol=atol rtol=rtol
    @test state.Gₛ ≈ reference.Gₛ atol=atol rtol=rtol
    @test state.Cᵢ ≈ reference.Cᵢ atol=atol rtol=rtol
    @test state.A ≈ reference_A(p, state.Cᵢ) atol=atol rtol=rtol
    @test state.Gₛ ≈ reference_gs(stomatal_model, state.A,
        state.Cₛ, state.Dₗ, leaf_water_potential) atol=atol rtol=rtol
    @test state.A ≈ state.Gₛ * (state.Cₛ - state.Cᵢ) atol=atol rtol=rtol
    return reference
end

function compensation_ppfd(model, temperature; Cs=400.0)
    p = reference_parameters(model, temperature, 0.0)
    J = 4 * p.Rd * (Cs + 2 * p.Γ) / (Cs - p.Γ)
    return J * (p.JMax - model.θ * J) / ((p.JMax - J) * model.α)
end

const ZERO_LIGHT_BOUNDARY_TEST_RESULT = @testset "Zero light also handles zero respiration and a zero stomatal intercept" begin
    no_respiration = Fvcb(VcMaxRef=120.0, JMaxRef=240.0, RdRef=0.0, TPURef=20.0)
    zero_intercept = Medlyn(0.0, 5.8, 0.001)
    for model in (no_respiration, parameterized_fvcb()), temperature in (15.0, 25.0, 40.0)
        state, _ = leaf_state(; temperature, ppfd=0.0, model, stomatal_model=zero_intercept)
        @test all(isfinite, (state.A, state.Gₛ, state.Cᵢ))
        @test state.A == -expected_respiration(temperature; model)
        @test state.Gₛ == 0.001
        @test state.Cᵢ ≈ state.Cₛ - state.A / state.Gₛ
        @test iszero(model.RdRef) ? state.Cᵢ == state.Cₛ : state.Cᵢ > state.Cₛ
    end
end

const DARK_TEST_RESULT = @testset "Original Fvcb at zero light with the configured Medlyn intercept" begin
    for temperature in 15.0:0.2:40.0
        state, _ = leaf_state(; temperature, ppfd=0.0)
        @test isfinite(state.A) && isfinite(state.Gₛ) && isfinite(state.Cᵢ)
        @test state.A == -expected_respiration(temperature)
        @test state.Gₛ == 0.001
        @test state.Cᵢ ≈ state.Cₛ - state.A / state.Gₛ
        @test state.Cᵢ > state.Cₛ
    end
end

const LOW_LIGHT_TEST_RESULT = @testset "Near-zero absorbed light remains finite and respiration dominated" begin
    for temperature in (15.0, 25.0, 40.0), ppfd in (1e-12, 1e-6, 1e-3)
        state, _ = leaf_state(; temperature, ppfd)
        @test all(isfinite, (state.A, state.Gₛ, state.Cᵢ))
        @test state.A ≈ -expected_respiration(temperature) atol=1e-3
        @test state.Gₛ == 0.001
        @test state.Cᵢ ≈ state.Cₛ - state.A / state.Gₛ
        @test state.A < 0 && state.Cᵢ > state.Cₛ
    end
end

const COUPLED_DARK_TEST_RESULT = @testset "Nighttime energy balance and negative leaf VPD stay finite" begin
    # Exercise Monteith's repeated unpublished photosynthesis hard calls in
    # cool/humid and warmer nighttime conditions.
    for (temperature, relative_humidity) in ((16.8, 0.9), (25.0, 0.65), (35.0, 0.45))
        state, scene = leaf_state(;
            temperature, ppfd=0.0, coupled_energy=true, relative_humidity)
        @test all(isfinite, (state.A, state.Gₛ, state.Cᵢ, state.Tₗ, state.λE))
        @test state.A ≈ -expected_respiration(state.Tₗ)
        @test state.Gₛ == 0.001
        @test PlantSimEngine.Authoring.validate_scenario(scene).valid
        @test state.Cᵢ ≈ state.Cₛ - state.A / state.Gₛ
        @test state.Cᵢ > state.Cₛ
    end

    # The leaf is colder than humid air, so its leaf-to-air VPD is negative.
    # Medlyn's existing closure clamp, rather than a new model, handles it.
    state, _ = leaf_state(;
        temperature=25.0, leaf_temperature=15.0,
        relative_humidity=0.9, ppfd=0.0,
    )
    @test state.Dₗ < 0.0
    @test all(isfinite, (state.A, state.Gₛ, state.Cᵢ))
    @test state.A == -expected_respiration(15.0)
    @test state.Gₛ == 0.001
    @test state.Cᵢ ≈ state.Cₛ - state.A / state.Gₛ
    @test state.Cᵢ > state.Cₛ
end

const DAYLIGHT_TEST_RESULT = @testset "Original Fvcb gives finite daytime assimilation" begin
    for temperature in (15.0, 25.0, 35.0), ppfd in (100.0, 500.0, 1500.0)
        state, _ = leaf_state(; temperature, ppfd)
        @test all(isfinite, (state.A, state.Gₛ, state.Cᵢ))
        @test state.A > 0.0
        @test state.Gₛ >= 0.001
    end
    state, scene = leaf_state(; temperature=25.0, ppfd=1500.0, coupled_energy=true)
    @test all(isfinite, (state.A, state.Gₛ, state.Cᵢ, state.Tₗ, state.λE))
    @test state.A > 0.0
    @test PlantSimEngine.Authoring.validate_scenario(scene).valid
end

const NEGATIVE_ASSIMILATION_TEST_RESULT = @testset "Positive gross photosynthesis below light compensation" begin
    model = parameterized_fvcb()
    stomatal_models = (
        Medlyn(0.0, 5.8, 0.001),
        Medlyn(0.03, 5.8, 0.001),
        Tuzet(0.03, 9.0, -1.5, 2.0, 40.0, 0.001),
        ConstantGs(0.0, 0.2),
    )
    for temperature in (15.0, 25.0, 40.0), stomatal_model in stomatal_models,
        fraction in (0.25, 0.75)
        ppfd = fraction * compensation_ppfd(model, temperature)
        state, _ = leaf_state(; temperature, ppfd, model, stomatal_model)
        check_equilibrium(state, model, stomatal_model, ppfd)
        @test -expected_respiration(temperature; model) < state.A < 0.0
        @test state.Cᵢ > state.Cₛ
    end
end

const COMPENSATION_TEST_RESULT = @testset "Assimilation crosses light compensation continuously" begin
    model = parameterized_fvcb()
    temperature = 25.0
    compensation = compensation_ppfd(model, temperature)
    for stomatal_model in (
        Medlyn(0.0, 5.8, 0.001), Medlyn(0.03, 5.8, 0.001),
        Tuzet(0.03, 9.0, -1.5, 2.0, 40.0, 0.001), ConstantGs(0.02, 0.2),
    )
        states = map((1 - 1e-6, 1.0, 1 + 1e-6)) do fraction
            ppfd = compensation * fraction
            state, _ = leaf_state(; temperature, ppfd, model, stomatal_model)
            check_equilibrium(state, model, stomatal_model, ppfd)
            state
        end
        below, at_compensation, above = states
        @test below.A < 0.0
        @test abs(at_compensation.A) < 1e-8
        @test above.A > 0.0
        @test abs(above.A - below.A) < 1e-4
        @test below.Cᵢ > below.Cₛ
        @test above.Cᵢ < above.Cₛ
    end
end

const STOMATAL_COUPLING_TEST_RESULT = @testset "Coupling is independent of an initial assimilation guess" begin
    model = parameterized_fvcb()
    compensation = compensation_ppfd(model, 25.0)
    for stomatal_model in (
        Medlyn(0.03, 5.8, 0.001),
        Tuzet(0.03, 9.0, -1.5, 2.0, 40.0, 0.001),
        ConstantGs(0.0, 0.2), ConstantGs(0.03, 0.2),
    ), initial_A in (nothing, 0.0, 37.0), ppfd in (0.0, 0.7 * compensation, 1500.0)
        state, _ = leaf_state(; temperature=25.0, ppfd, model, stomatal_model, initial_A)
        @test all(isfinite, (state.A, state.Gₛ, state.Cᵢ))
        check_equilibrium(state, model, stomatal_model, ppfd)
    end

    # Changing ConstantGs' unused intercept cannot change its fixed conductance
    # or the coupled solution. Its published Gs is not divided by an initial A.
    for ppfd in (0.0, 10.0, 1500.0)
        a, _ = leaf_state(; temperature=25.0, ppfd, initial_A=nothing,
            stomatal_model=ConstantGs(0.0, 0.2))
        b, _ = leaf_state(; temperature=25.0, ppfd, initial_A=0.0,
            stomatal_model=ConstantGs(0.03, 0.2))
        @test a.Gₛ == b.Gₛ == 0.2
        @test a.A ≈ b.A
        @test a.Cᵢ ≈ b.Cᵢ
    end
end

const LIMITATION_AND_FLOOR_TEST_RESULT = @testset "Rubisco, electron transport, TPU and conductance floors remain coupled" begin
    cases = (
        # Rubisco-limited with large available electron transport.
        (model=Fvcb(VcMaxRef=20.0, JMaxRef=240.0, RdRef=1.2, TPURef=20.0),
            stomatal_model=Medlyn(0.03, 5.8, 0.001), ppfd=1500.0, Cs=400.0),
        # A small TPU capacity, while keeping the ordinary respiration rate.
        (model=Fvcb(VcMaxRef=120.0, JMaxRef=240.0, RdRef=1.2, TPURef=2.0),
            stomatal_model=Tuzet(0.03, 9.0, -1.5, 2.0, 40.0, 0.001), ppfd=1500.0, Cs=400.0),
        # A prescribed floor exceeds the intercept even during assimilation.
        (model=parameterized_fvcb(), stomatal_model=Medlyn(0.0, 1.0, 0.1),
            ppfd=100.0, Cs=600.0),
        (model=parameterized_fvcb(), stomatal_model=Tuzet(0.0, 1.0, -1.5, 2.0, 40.0, 0.05),
            ppfd=50.0, Cs=250.0),
    )
    for case in cases
        state, _ = leaf_state(; temperature=25.0, ppfd=case.ppfd,
            model=case.model, stomatal_model=case.stomatal_model, surface_co2=case.Cs)
        check_equilibrium(state, case.model, case.stomatal_model, case.ppfd)
    end

    # A negative fitted intercept can admit more than one algebraic branch.
    # Check the complete physiological equations, without assuming that a
    # single whole-domain bisection would select the admissible branch.
    model = parameterized_fvcb()
    compensation = compensation_ppfd(model, 25.0)
    for stomatal_model in (
        Medlyn(-0.01, 5.8, 0.001),
        Tuzet(-0.03, 12.0, -1.5, 2.0, 40.0, 0.005),
    ), ppfd in (0.0, 0.4 * compensation, 500.0, 1500.0)
        state, _ = leaf_state(; temperature=25.0, ppfd, model, stomatal_model, initial_A=nothing)
        p = reference_parameters(model, state.Tₗ, ppfd)
        @test all(isfinite, (state.A, state.Gₛ, state.Cᵢ))
        @test state.Cᵢ > 0.0
        @test state.Gₛ >= stomatal_model.gs_min
        @test state.A ≈ reference_A(p, state.Cᵢ) atol=1e-8 rtol=2e-8
        @test state.Gₛ ≈ reference_gs(stomatal_model, state.A,
            state.Cₛ, state.Dₗ, -1.0) atol=1e-8 rtol=2e-8
        @test state.A ≈ state.Gₛ * (state.Cₛ - state.Cᵢ) atol=1e-8 rtol=2e-8
    end
end

const FLOAT32_COUPLING_TEST_RESULT = @testset "Coupled outputs preserve Float32 carriers" begin
    original = parameterized_fvcb()
    model = Fvcb(; (name => Float32(getproperty(original, name))
        for name in fieldnames(typeof(original)))...)
    for stomatal_model in (
        Medlyn(0.03f0, 5.8f0, 0.001f0),
        Tuzet(0.03f0, 9f0, -1.5f0, 2f0, 40f0, 0.001f0),
        ConstantGs(0f0, 0.2f0),
    ), ppfd in (0f0, 5f0, 1500f0)
        state, _ = leaf_state(; temperature=25f0, ppfd, model, stomatal_model,
            initial_A=nothing, scalar_type=Float32)
        @test all(value -> value isa Float32, (state.A, state.Gₛ, state.Cᵢ))
        check_equilibrium(state, model, stomatal_model, ppfd; atol=5e-6, rtol=3e-5)
    end
end

const LINEAR_COUPLING_TEST_RESULT = @testset "A zero quadratic coefficient still solves the physiological equations" begin
    # For the electron-transport branch, slope*(Cs + 2Γ) - 1 == 0.
    # All values used to cancel this coefficient are binary-exact, so this
    # genuinely exercises the linear limit rather than a small quadratic.
    for T in (Float32, Float64)
        VcMax, Vj, Γ, Cs, Rd, Km, TPU = T.((120, 3, 56, 400, 1.2, 700, 20))
        g0, slope, gs_min = T(0.03), inv(T(512)), T(0.001)
        @test slope * (Cs + 2 * Γ) - one(T) == zero(T)
        A = PlantBiophysics._fvcb_assimilation(
            VcMax, Vj, Γ, Cs, Rd, Km, TPU, g0, slope, gs_min)
        Gs = max(gs_min, g0 + slope * A)
        Ci = Cs - A / Gs
        biochemical_A = min(VcMax * (Ci - Γ) / (Ci + Km),
            Vj * (Ci - Γ) / (Ci + 2 * Γ), 3 * TPU) - Rd
        @test A isa T
        @test all(isfinite, (A, Gs, Ci))
        @test zero(T) < A && zero(T) < Ci < Cs
        @test A ≈ biochemical_A atol=T(5e-6) rtol=T(3e-5)
        @test A ≈ Gs * (Cs - Ci) atol=T(5e-6) rtol=T(3e-5)
    end
end

const PARTICLE_COUPLING_TEST_RESULT = @testset "Each uncertainty particle selects its own assimilation and conductance branch" begin
    model = parameterized_fvcb()
    stomatal_model = Medlyn(0.0, 5.8, 0.001)
    temperature, Cs, Dl, Ψₗ = 25.0, 400.0, 1.0, -1.0
    slope = (1 + stomatal_model.g1 / sqrt(Dl)) / Cs
    ppfd_values = [0.0, 10.0, 20.0, 1500.0]
    scalar_parameters = map(ppfd_values) do ppfd
        p = reference_parameters(model, temperature, ppfd)
        (p.VcMax, p.Vj, p.Γ, Cs, p.Rd, p.Km, p.TPU,
            stomatal_model.g0, slope, stomatal_model.gs_min)
    end
    scalar_A = [PlantBiophysics._fvcb_assimilation(parameters...)
        for parameters in scalar_parameters]
    reference_values = [bisection_reference(model, stomatal_model,
        temperature, ppfd, Cs, Dl, Ψₗ).A for ppfd in ppfd_values]
    for ParticleType in (Particles, StaticParticles)
        parameters = ntuple(column -> ParticleType([
            values[column] for values in scalar_parameters]), 10)
        ensemble = PlantBiophysics._fvcb_assimilation(parameters...)
        values = collect(ensemble.particles)
        conductances = max.(stomatal_model.gs_min, stomatal_model.g0 .+ slope .* values)
        @test ensemble isa ParticleType{Float64,4}
        @test all(isfinite, values)
        @test values ≈ scalar_A atol=1e-12 rtol=1e-12
        @test values ≈ reference_values atol=1e-8 rtol=2e-8
        @test values[1] == -expected_respiration(temperature)
        @test values[2] < 0.0 < values[3] < values[4]
        @test all(==(stomatal_model.gs_min), conductances[1:2])
        @test all(>(stomatal_model.gs_min), conductances[3:4])
    end
end

const ZERO_CONDUCTANCE_TEST_RESULT = @testset "Zero conductance admits zero exchange but cannot export respired carbon" begin
    for T in (Float32, Float64)
        parameters = T.((120, 0, 42.75, 400, 1.2, 700, 20, 0, 0, 0))
        @test_throws DomainError PlantBiophysics._fvcb_assimilation(parameters...)
        VcMax, Vj, Γ, Cs, _, Km, TPU, g0, slope, gs_min = parameters
        A = PlantBiophysics._fvcb_assimilation(
            VcMax, Vj, Γ, Cs, zero(T), Km, TPU, g0, slope, gs_min)
        @test iszero(A)
        @test A isa T
    end
end

const PARTICLE_ZERO_EXCHANGE_TEST_RESULT = @testset "Particle Ci handles dark zero exchange alongside assimilating particles" begin
    model = Fvcb(VcMaxRef=120.0, JMaxRef=240.0, RdRef=0.0, TPURef=20.0)
    Cs, slope = 400.0, 6.8 / 400.0
    ppfd_values = [0.0, 10.0, 20.0, 1500.0]
    biochemical = [reference_parameters(model, 25.0, ppfd) for ppfd in ppfd_values]
    scalar_parameters = [(p.VcMax, p.Vj, p.Γ, Cs, p.Rd, p.Km, p.TPU,
        0.0, slope, 0.0) for p in biochemical]
    scalar_A = [PlantBiophysics._fvcb_assimilation(parameters...)
        for parameters in scalar_parameters]
    scalar_Gs = slope .* scalar_A
    scalar_Ci = [PlantBiophysics._fvcb_ci(Cs, A, Gs)
        for (A, Gs) in zip(scalar_A, scalar_Gs)]
    for ParticleType in (Particles, StaticParticles)
        parameters = ntuple(column -> ParticleType([
            values[column] for values in scalar_parameters]), 10)
        A = PlantBiophysics._fvcb_assimilation(parameters...)
        Gs = slope * A
        Ci = PlantBiophysics._fvcb_ci(Cs, A, Gs)
        values = collect(Ci.particles)
        @test Ci isa ParticleType{Float64,4}
        @test all(isfinite, values)
        @test collect(A.particles) ≈ scalar_A atol=1e-12 rtol=1e-12
        @test collect(Gs.particles) ≈ scalar_Gs atol=1e-12 rtol=1e-12
        @test values ≈ scalar_Ci atol=1e-12 rtol=1e-12
        @test values[1] == Cs
        @test A.particles[1] == Gs.particles[1] == 0.0
        @test all(Ci -> Ci ≈ Cs - inv(slope), values[2:4])
        @test all(i -> A.particles[i] ≈ reference_A(biochemical[i], values[i]), 1:4)
    end
end

end # module FvcbRegressionTests
