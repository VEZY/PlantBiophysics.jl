A = Fvcb(α=0.24)
Gs = Medlyn(0.03, 12.0)

@testset "leaf_scene" begin
    scene = leaf_scene(
        A,
        Gs;
        status=Status(Tₗ=25.0, aPPFD=1000.0, Cₛ=400.0, Dₗ=1.2),
    )
    applications = explain_applications(Advanced.compile_composite_model(scene))
    @test Set(row.application_id for row in applications) ==
          Set([:photosynthesis, :stomatal_conductance])
    @test only(
        row for row in applications
        if row.application_id == :photosynthesis
    ).model_type == Fvcb{Float64}
    @test only(
        row for row in applications
        if row.application_id == :stomatal_conductance
    ).model_type == Medlyn{Float64}
end

@testset "Generated and initialized status" begin
    scene = leaf_scene(
        A,
        Gs;
        status=Status(Tₗ=25.0, aPPFD=1000.0, Cₛ=400.0, Dₗ=1.2),
    )
    compiled = Advanced.compile_composite_model(scene)
    @test compiled isa Advanced.CompiledCompositeModel
    @test leaf_status(scene).Tₗ == 25.0
end

@testset "NamedTuple and DataFrame rows initialize equivalently" begin
    meteo = Atmosphere(
        T=20.0,
        Wind=1.0,
        P=101.3,
        Rh=0.65,
        duration=Hour(1),
    )
    values = (
        Ra_SW_f=13.747,
        sky_fraction=1.0,
        d=0.03,
        aPPFD=1300.0,
    )
    dataframe = DataFrame([values])
    dataframe_values = NamedTuple(first(eachrow(dataframe)))

    scene_named = leaf_scene(
        Monteith(),
        Fvcb(α=0.24),
        Medlyn(0.03, 12.0);
        status=Status(; values...),
        environment=meteo,
    )
    scene_dataframe = leaf_scene(
        Monteith(),
        Fvcb(α=0.24),
        Medlyn(0.03, 12.0);
        status=Status(; dataframe_values...),
        environment=meteo,
    )
    run!(scene_named; constants=Constants())
    run!(scene_dataframe; constants=Constants())
    @test NamedTuple(leaf_status(scene_named)) ==
          NamedTuple(leaf_status(scene_dataframe))
end
