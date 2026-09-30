@testset "Model hard-call defaults" begin
    @test dep(Monteith()).photosynthesis isa Call
    @test dep(Fvcb()).stomatal_conductance isa Call
    @test dep(FvcbIter()).stomatal_conductance isa Call
    @test dep(ConstantAGs()).stomatal_conductance isa Call
end

@testset "Compiled leaf hard-call graph" begin
    scene = CompositeModel(
        Monteith(),
        Fvcb(α=0.24),
        Medlyn(0.03, 12.0);
        status=Status(
            Ra_SW_f=13.747,
            sky_fraction=1.0,
            d=0.03,
            aPPFD=1500.0,
        ),
        environment=Atmosphere(
            T=20.0,
            Wind=1.0,
            P=101.3,
            Rh=0.65,
            duration=Hour(1),
        ),
    )
    compiled = Advanced.compile_composite_model(scene)
    calls = PlantSimEngine.Diagnostics.explain_calls(compiled)
    @test only(
        row for row in calls
        if row.application_id == :energy_balance
    ).callee_application_ids == [:photosynthesis]
    @test only(
        row for row in calls
        if row.application_id == :photosynthesis
    ).callee_application_ids == [:stomatal_conductance]

    simulation = run!(scene; outputs=:all)
    published_applications = Set(
        row.application_id for row in collect_outputs(simulation; sink=nothing)
    )
    @test :energy_balance in published_applications
    @test :photosynthesis ∉ published_applications
    @test :stomatal_conductance ∉ published_applications
end

@testset "Hard calls do not require a Leaf scale label" begin
    initial = (Ra_SW_f=13.747, sky_fraction=1.0, aPPFD=1500.0, d=0.03)
    atmosphere = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, duration=Hour(1))
    weather = Weather([
        Atmosphere(T=20.0 + i, Wind=1.0, P=101.3, Rh=0.65, duration=Hour(1))
        for i in 0:5
    ])
    samples(sim) = [
        (row.application_id, row.object_id, row.variable, row.timestep, row.datetime, row.value)
        for row in collect_outputs(sim; sink=nothing)
    ]

    for photosynthesis in (Fvcb(), FvcbIter(), ConstantAGs())
        @testset "$(nameof(typeof(photosynthesis)))" begin
            for (environment, run_options, expected_steps) in (
                (atmosphere, NamedTuple(), 1),
                (weather, NamedTuple(), 1),
                (weather, (steps=6,), 6),
            )
                reference = run!(CompositeModel(
                    Monteith(), photosynthesis, Medlyn(0.03, 12.0);
                    scale=:Leaf, status=initial, environment=environment,
                ); outputs=:all, run_options...)
                for labels in (NamedTuple(), (scale=:Lamina,))
                    scene = CompositeModel(
                        Monteith(), photosynthesis, Medlyn(0.03, 12.0);
                        status=initial, environment=environment, labels...,
                    )
                    simulation = run!(scene; outputs=:all, run_options...)
                    @test final_state(simulation) == final_state(reference)
                    rows = collect_outputs(simulation; sink=nothing)
                    @test samples(simulation) == samples(reference)
                    @test maximum(row.timestep for row in rows) == expected_steps
                end
            end
        end
    end
end

@testset "Default hard calls stay on their own object" begin
    environment = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, duration=Hour(1))
    objects = (
        (id=:leaf, scale=:Leaf, aPPFD=1500.0),
        (id=:lamina, scale=:Lamina, aPPFD=800.0),
        (id=:sample, scale=:Scene, aPPFD=300.0),
    )
    initial(aPPFD) = (Ra_SW_f=13.747, sky_fraction=1.0, aPPFD=aPPFD, d=0.03)

    for photosynthesis in (Fvcb(), FvcbIter(), ConstantAGs())
        @testset "$(nameof(typeof(photosynthesis)))" begin
            scene = CompositeModel(
                (Object(object.id; scale=object.scale, status=Status(initial(object.aPPFD)))
                 for object in objects)...;
                applications=(
                    ModelSpec(Monteith(); on=Many()),
                    ModelSpec(photosynthesis; on=Many()),
                    ModelSpec(Medlyn(0.03, 12.0); on=Many()),
                ),
                environment=environment,
            )
            calls = PlantSimEngine.Diagnostics.explain_calls(scene)
            @test length(calls) == 2 * length(objects)
            @test all(row -> row.callee_object_ids == [row.consumer_id], calls)

            simulation = run!(scene; outputs=:all)
            for object in objects
                reference = run!(CompositeModel(
                    Monteith(), photosynthesis, Medlyn(0.03, 12.0);
                    scale=:Leaf, status=initial(object.aPPFD), environment=environment,
                ); outputs=:all)
                @test final_state(simulation, object.id) == final_state(reference)
            end
        end
    end
end
