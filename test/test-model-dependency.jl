@testset "Model hard-call defaults" begin
    @test dep(Monteith()).photosynthesis isa Call
    @test dep(Fvcb()).stomatal_conductance isa Call
    @test dep(FvcbIter()).stomatal_conductance isa Call
    @test dep(ConstantAGs()).stomatal_conductance isa Call
end

@testset "Compiled leaf hard-call graph" begin
    scene = leaf_scene(
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
    calls = explain_calls(compiled)
    @test only(
        row for row in calls
        if row.application_id == :energy_balance
    ).callee_application_ids == [:photosynthesis]
    @test only(
        row for row in calls
        if row.application_id == :photosynthesis
    ).callee_application_ids == [:stomatal_conductance]

    bundle = only(
        row for row in explain_model_bundles(compiled)
        if row.application_id == :energy_balance
    )
    @test bundle.processes ==
          [:energy_balance, :photosynthesis, :stomatal_conductance]

    simulation = run!(scene; outputs=:all)
    published_applications = Set(
        row.application_id for row in collect_outputs(simulation; sink=nothing)
    )
    @test :energy_balance in published_applications
    @test :photosynthesis ∉ published_applications
    @test :stomatal_conductance ∉ published_applications
end
