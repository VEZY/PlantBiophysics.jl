@testset "Constant absorption equations and model boundary" begin
    model = ConstantAbsorption(; α_PAR=0.8, α_NIR=0.25)
    constants = Constants(J_to_umol=4.0)
    status = Status(PlantSimEngine.outputs_(model))

    @test model isa AbstractLight_InterceptionModel
    @test PlantSimEngine.inputs_(model) == NamedTuple()
    @test Tuple(environment_inputs(model)) == (:Ri_PAR_f, :Ri_NIR_f)
    @test variable_contracts(model).aPPFD == PlantBiophysics.LEAF_PAR_PHOTON_FLUX_CONTRACT
    @test variable_contracts(model).Ra_SW_f == PlantBiophysics.LEAF_IRRADIANCE_CONTRACT
    @test PlantSimEngine.Authoring.validate_model(model).valid

    result = PlantSimEngine.run!(
        model, status, (Ri_PAR_f=200.0, Ri_NIR_f=400.0), constants, nothing,
    )
    @test result === nothing
    @test status.Ra_PAR_f ≈ 160.0
    @test status.Ra_NIR_f ≈ 100.0
    @test status.Ra_SW_f ≈ 260.0
    @test status.aPPFD ≈ 640.0

    # Darkness must replace every previous output, including band diagnostics.
    PlantSimEngine.run!(
        model, status, (Ri_PAR_f=0.0, Ri_NIR_f=0.0), constants, nothing,
    )
    @test all(iszero, values(NamedTuple(status)))

    # Each band can be unabsorbed or fully absorbed independently.
    for (α_PAR, α_NIR, expected_PAR, expected_NIR) in (
        (0, 0, 0.0, 0.0),
        (1, 0, 200.0, 0.0),
        (0, 1, 0.0, 400.0),
        (1, 1, 200.0, 400.0),
    )
        endpoint_model = ConstantAbsorption(α_PAR, α_NIR)
        endpoint_status = Status(PlantSimEngine.outputs_(endpoint_model))
        PlantSimEngine.run!(
            endpoint_model, endpoint_status,
            (Ri_PAR_f=200.0, Ri_NIR_f=400.0), constants, nothing,
        )
        @test endpoint_status.Ra_PAR_f == expected_PAR
        @test endpoint_status.Ra_NIR_f == expected_NIR
        @test endpoint_status.Ra_SW_f == expected_PAR + expected_NIR
        @test endpoint_status.aPPFD == expected_PAR * 4.0
    end
end

@testset "Constant absorption rejects invalid fractions and radiation" begin
    for invalid in (-0.01, 1.01, Inf, -Inf, NaN)
        @test_throws DomainError ConstantAbsorption(invalid, 0.25)
        @test_throws DomainError ConstantAbsorption(0.8, invalid)
        @test_throws DomainError ConstantAbsorption(; α_PAR=invalid, α_NIR=0.25)
        @test_throws DomainError ConstantAbsorption(; α_PAR=0.8, α_NIR=invalid)
    end

    model = ConstantAbsorption(0.8, 0.25)
    for invalid in (-1.0, Inf, -Inf, NaN)
        for environment in (
            (Ri_PAR_f=invalid, Ri_NIR_f=400.0),
            (Ri_PAR_f=200.0, Ri_NIR_f=invalid),
        )
            status = Status(PlantSimEngine.outputs_(model))
            @test_throws DomainError PlantSimEngine.run!(
                model, status, environment, Constants(), nothing,
            )
        end
    end
end

@testset "Constant absorption preserves Float32" begin
    model = ConstantAbsorption(; α_PAR=0.8f0, α_NIR=0.25f0)
    @test model.α_PAR isa Float32
    @test model.α_NIR isa Float32
    @test all(value -> value isa Float32, values(PlantSimEngine.outputs_(model)))

    scene = CompositeModel(
        model;
        environment=(Ri_PAR_f=200.0f0, Ri_NIR_f=400.0f0, duration=Hour(1)),
    )
    status = final_state(run!(scene; constants=Constants{Float32}(J_to_umol=4.0f0)))
    for (variable, expected) in (
        :Ra_PAR_f => 160.0f0, :Ra_NIR_f => 100.0f0,
        :Ra_SW_f => 260.0f0, :aPPFD => 640.0f0,
    )
        @test status[variable] isa Float32
        @test status[variable] ≈ expected
    end
end

@testset "Constant absorption returns rates independently of step duration" begin
    for duration in (Minute(1), Hour(1), Day(1))
        scene = CompositeModel(
            ConstantAbsorption(0.8, 0.25);
            environment=(Ri_PAR_f=200.0, Ri_NIR_f=400.0, duration=duration),
        )
        status = final_state(run!(scene; constants=Constants(J_to_umol=4.0)))
        @test status.Ra_PAR_f ≈ 160.0
        @test status.Ra_NIR_f ≈ 100.0
        @test status.Ra_SW_f ≈ 260.0
        @test status.aPPFD ≈ 640.0
        @test !hasproperty(status, :LAI)
    end
end

@testset "Constant absorption supplies current weather to coupled physiology" begin
    constants = Constants()
    weather_rows = [
        Atmosphere(
            T=T, Wind=1.0, P=101.3, Rh=0.65,
            Ri_PAR_f=par, Ri_NIR_f=nir, duration=Hour(1),
        )
        for (T, par, nir) in (
            (20.0, 80.0, 300.0),
            (25.0, 360.0, 100.0),
            (22.0, 150.0, 420.0),
        )
    ]
    weather = Weather(weather_rows)
    scene = CompositeModel(
        Monteith(), Fvcb(), Medlyn(0.03, 12.0),
        # Declare light last to test dependency scheduling, not tuple order.
        ConstantAbsorption(; α_PAR=0.8, α_NIR=0.25);
        status=Status(sky_fraction=1.0, d=0.03),
        environment=weather,
    )
    simulation = run!(scene; steps=length(weather), constants=constants, outputs=:all)
    # Monteith initializes the inputs of its hard-called physiology models.
    @test PlantSimEngine.Authoring.validate_scenario(scene).valid
    @test current_step(simulation) == length(weather_rows)
    rows = collect_outputs(simulation; sink=nothing)

    for (timestep, environment) in enumerate(weather_rows)
        absorbed_PAR = 0.8 * environment.Ri_PAR_f
        absorbed_NIR = 0.25 * environment.Ri_NIR_f
        radiation = (
            Ra_PAR_f=absorbed_PAR,
            Ra_NIR_f=absorbed_NIR,
            Ra_SW_f=absorbed_PAR + absorbed_NIR,
            aPPFD=absorbed_PAR * constants.J_to_umol,
        )
        for variable in keys(radiation)
            actual = only(
                row.value for row in rows
                if row.application_id == :light_interception &&
                   row.variable == variable && row.timestep == timestep
            )
            @test actual ≈ radiation[variable]
        end

        # Independent leaf runs use the same absorbed radiation as prescribed
        # inputs, without the new model or any result from its simulation.
        reference_scene = CompositeModel(
            Monteith(), Fvcb(), Medlyn(0.03, 12.0);
            status=Status(
                sky_fraction=1.0, d=0.03,
                aPPFD=radiation.aPPFD, Ra_SW_f=radiation.Ra_SW_f,
            ),
            environment=environment,
        )
        reference = final_state(run!(reference_scene; constants=constants))
        for variable in (:Rn, :H, :λE, :Tₗ, :A, :Gₛ)
            actual = only(
                row.value for row in rows
                if row.application_id == :energy_balance &&
                   row.variable == variable && row.timestep == timestep
            )
            @test isfinite(actual)
            @test actual ≈ reference[variable] rtol = 1e-10 atol = 1e-10
        end
    end
end
