module FvcbRegressionTests

using Test
using Dates
using PlantBiophysics
using PlantBiophysics.PlantMeteo
using PlantBiophysics.PlantSimEngine

parameterized_fvcb() = Fvcb(VcMaxRef=120.0, JMaxRef=240.0, RdRef=1.2, TPURef=20.0)
configured_medlyn() = Medlyn(1e-6, 5.8, 0.001)

function leaf_state(;
    temperature, ppfd, coupled_energy=false, relative_humidity=0.65,
    leaf_temperature=temperature,
    model=parameterized_fvcb(), stomatal_model=configured_medlyn(),
)
    environment = Atmosphere(
        T=temperature, Wind=0.8, P=101.325, Rh=relative_humidity,
        Cₐ=400.0, duration=Hour(1),
    )
    leaf_vpd = PlantMeteo.e_sat(leaf_temperature) -
               PlantMeteo.e_sat(temperature) * relative_humidity
    status = Status(
        aPPFD=ppfd, Tₗ=leaf_temperature, Cₛ=400.0, A=0.0, Dₗ=leaf_vpd,
        d=0.01, Ra_SW_f=ppfd / PlantMeteo.Constants().J_to_umol,
        sky_fraction=0.5,
    )
    models = coupled_energy ? (Monteith(aₛᵥ=2), model, stomatal_model) :
        (model, stomatal_model)
    scene = CompositeModel(models...; status, environment)
    simulation = PlantSimEngine.run!(scene; steps=1, outputs=:none)
    return final_state(simulation), scene
end

function expected_respiration(temperature; model=parameterized_fvcb())
    constants = PlantMeteo.Constants()
    return PlantBiophysics.arrhenius(
        model.RdRef, model.Eₐᵣ,
        temperature - constants.K₀, model.Tᵣ - constants.K₀, constants.R,
    )
end

const ZERO_LIGHT_BOUNDARY_TEST_RESULT = @testset "Zero light also handles zero respiration and a zero stomatal intercept" begin
    no_respiration = Fvcb(VcMaxRef=120.0, JMaxRef=240.0, RdRef=0.0, TPURef=20.0)
    zero_intercept = Medlyn(0.0, 5.8, 0.001)
    for model in (no_respiration, parameterized_fvcb()), temperature in (15.0, 25.0, 40.0)
        state, _ = leaf_state(; temperature, ppfd=0.0, model, stomatal_model=zero_intercept)
        @test all(isfinite, (state.A, state.Gₛ, state.Cᵢ))
        @test state.A == -expected_respiration(temperature; model)
        @test state.Gₛ == 0.001
        @test state.Cᵢ == state.Cₛ
    end
end

const DARK_TEST_RESULT = @testset "Original Fvcb at zero light with the configured Medlyn intercept" begin
    for temperature in 15.0:0.2:40.0
        state, _ = leaf_state(; temperature, ppfd=0.0)
        @test isfinite(state.A) && isfinite(state.Gₛ) && isfinite(state.Cᵢ)
        @test state.A == -expected_respiration(temperature)
        @test state.Gₛ == 0.001
        @test state.Cᵢ == state.Cₛ
    end
end

const LOW_LIGHT_TEST_RESULT = @testset "Near-zero absorbed light remains finite and respiration dominated" begin
    for temperature in (15.0, 25.0, 40.0), ppfd in (1e-12, 1e-6, 1e-3)
        state, _ = leaf_state(; temperature, ppfd)
        @test all(isfinite, (state.A, state.Gₛ, state.Cᵢ))
        @test state.A ≈ -expected_respiration(temperature) atol=1e-3
        @test state.Gₛ == 0.001
        @test state.Cᵢ == state.Cₛ
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

end # module FvcbRegressionTests
