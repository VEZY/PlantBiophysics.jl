PlantSimEngine.@process "dailyassimintegratortest" verbose = false
struct DailyAssimIntegratorTestModel <: AbstractDailyassimintegratortestModel end
PlantSimEngine.inputs_(::DailyAssimIntegratorTestModel) = (A_integrated=-Inf,)
PlantSimEngine.outputs_(::DailyAssimIntegratorTestModel) = (A_daily=-Inf,)
function PlantSimEngine.run!(::DailyAssimIntegratorTestModel, models, status, meteo, constants=nothing, extra=nothing)
    status.A_daily = status.A_integrated
    nothing
end

@testset "Multi-rate timestep hints" begin
    hourly_pref = Dates.Hour(1)
    fast_range = (Dates.Minute(1), Dates.Hour(6))
    energy_range = (Dates.Minute(1), Dates.Hour(2))

    @test PlantSimEngine.timestep_hint(Monteith()) == (required=energy_range, preferred=hourly_pref)

    @test PlantSimEngine.timestep_hint(Fvcb()) == (required=fast_range, preferred=hourly_pref)
    @test PlantSimEngine.timestep_hint(FvcbIter()) == (required=fast_range, preferred=hourly_pref)
    @test PlantSimEngine.timestep_hint(FvcbRaw()) == (required=fast_range, preferred=hourly_pref)
    @test PlantSimEngine.timestep_hint(ConstantA()) == (required=fast_range, preferred=hourly_pref)
    @test PlantSimEngine.timestep_hint(ConstantAGs()) == (required=fast_range, preferred=hourly_pref)

    @test PlantSimEngine.output_policy(Monteith()).A isa Integrate
    @test PlantSimEngine.output_policy(Fvcb()).A isa Integrate
    @test PlantSimEngine.output_policy(Medlyn(0.03, 12.0)).Gₛ isa Aggregate

    @test PlantSimEngine.timestep_hint(Medlyn(0.03, 12.0)) == (required=fast_range, preferred=hourly_pref)
    @test PlantSimEngine.timestep_hint(Tuzet(0.03, 12.0, -1.5, 2.0, 30.0)) == (required=fast_range, preferred=hourly_pref)
    @test PlantSimEngine.timestep_hint(ConstantGs(0.0, 0.1)) == (required=fast_range, preferred=hourly_pref)
end

@testset "Multi-rate hourly leaf + daily integration" begin
    mtg = Node(NodeMTG("/", "Scene", 1, 0))
    plant = Node(mtg, NodeMTG("+", "Plant", 1, 1))
    internode = Node(plant, NodeMTG("/", "Internode", 1, 2))
    Node(internode, NodeMTG("+", "Leaf", 1, 2))

    meteo = Weather([
        Atmosphere(
            T=25.0,
            Wind=1.0,
            P=101.3,
            Rh=0.6,
            Cₐ=400.0,
            Ri_SW_f=300.0,
            duration=Dates.Hour(1)
        ) for _ in 1:48
    ])

    mapping = ModelMapping(
        "Leaf" => (
            Monteith(),
            Fvcb(),
            Medlyn(0.03, 12.0),
            ModelSpec(DailyAssimIntegratorTestModel()) |>
            TimeStepModel(Dates.Day(1)) |>
            InputBindings(; A_integrated=(process=:energy_balance, var=:A, policy=Integrate(vals -> sum(vals) * 3600.0))),
            Status(
                d=0.03,
                Ra_SW_f=150.0,
                sky_fraction=1.0,
                aPPFD=1200.0,
                A_integrated=0.0
            )
        ),
    )

    sim = PlantSimEngine.GraphSimulation(
        mtg,
        mapping,
        nsteps=length(meteo),
        check=true,
        outputs=Dict("Leaf" => (:A, :A_daily)),
    )

    out = run!(sim, meteo, executor=SequentialEx())
    out_df = convert_outputs(out, DataFrame)["Leaf"]

    @test nrow(out_df) == 48
    @test out_df.A_daily[1] ≈ out_df.A[1] * 3600.0 atol = 1e-4
    @test all(out_df.A_daily[1:24] .== out_df.A_daily[1])
    @test all(out_df.A_daily[25:48] .== out_df.A_daily[25])
    @test out_df.A_daily[25] ≈ 24.0 * out_df.A[1] * 3600.0 atol = 1e-3
    @test sim.temporal_state.last_run[ModelKey(ScopeId(:global, 1), "Leaf", :dailyassimintegratortest)] == 25.0

    specs = PlantSimEngine.get_model_specs(sim)["Leaf"]
    @test isnothing(PlantSimEngine.timestep(specs[:energy_balance]))
    @test isnothing(PlantSimEngine.timestep(specs[:photosynthesis]))
    @test isnothing(PlantSimEngine.timestep(specs[:stomatal_conductance]))
    @test PlantSimEngine.timestep(specs[:dailyassimintegratortest]) == Dates.Day(1)
end
