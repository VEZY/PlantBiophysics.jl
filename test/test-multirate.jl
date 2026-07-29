PlantSimEngine.@process "dailyleafsummarytest" verbose = false
struct DailyLeafSummaryTestModel <: AbstractDailyleafsummarytestModel end
PlantSimEngine.inputs_(::DailyLeafSummaryTestModel) = (
    A_integrated=-Inf,
    transpiration_integrated=-Inf,
    Tₗ_mean=-Inf,
    Tₗ_max=-Inf,
    Tₗ_min=-Inf,
)
PlantSimEngine.outputs_(::DailyLeafSummaryTestModel) = (
    A_daily=-Inf,
    transpiration_daily=-Inf,
    Tₗ_mean_daily=-Inf,
    Tₗ_max_daily=-Inf,
    Tₗ_min_daily=-Inf,
)
function PlantSimEngine.run!(::DailyLeafSummaryTestModel, status, environment, constants=nothing, context=nothing)
    status.A_daily = status.A_integrated
    status.transpiration_daily = status.transpiration_integrated
    status.Tₗ_mean_daily = status.Tₗ_mean
    status.Tₗ_max_daily = status.Tₗ_max
    status.Tₗ_min_daily = status.Tₗ_min
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
    @test PlantSimEngine.output_policy(Medlyn(0.03, 12.0)).Gₛ isa Integrate

    @test PlantSimEngine.timestep_hint(Medlyn(0.03, 12.0)) == (required=fast_range, preferred=hourly_pref)
    @test PlantSimEngine.timestep_hint(Tuzet(0.03, 12.0, -1.5, 2.0, 30.0)) == (required=fast_range, preferred=hourly_pref)
    @test PlantSimEngine.timestep_hint(ConstantGs(0.0, 0.1)) == (required=fast_range, preferred=hourly_pref)
end

@testset "Multi-rate hourly leaf + daily summary" begin
    mtg = Node(NodeMTG(:/, :Scene, 1, 0))
    plant = Node(mtg, NodeMTG(:+, :Plant, 1, 1))
    internode = Node(plant, NodeMTG(:/, :Internode, 1, 2))
    Node(internode, NodeMTG(:+, :Leaf, 1, 2))

    rh_day1 = [0.75 - 0.20 * max(0.0, sin((hour - 6.0) / 12.0 * pi)) for hour in 0:23]
    rh_day2 = rh_day1 .- 0.10
    wind_day1 = [0.8 + 0.4 * max(0.0, sin((hour - 6.0) / 12.0 * pi)) for hour in 0:23]
    wind_day2 = wind_day1 .+ 0.2
    Rh = vcat(rh_day1, rh_day2)
    Wind = vcat(wind_day1, wind_day2)

    environment = Weather([
        Atmosphere(
            T=25.0,
            Wind=Wind[i],
            P=101.3,
            Rh=Rh[i],
            Cₐ=400.0,
            Ri_SW_f=300.0,
            duration=Dates.Hour(1)
        ) for i in 1:48
    ])

    λ_ref = environment[1].λ

    scene = CompositeModel(
        Object(
            :leaf;
            scale=:Leaf,
            kind=:plant,
            status=Status(
                d=0.03,
                Ra_SW_f=150.0,
                sky_fraction=1.0,
                aPPFD=1200.0,
                A_integrated=0.0,
                transpiration_integrated=0.0,
                Tₗ_mean=0.0,
                Tₗ_max=0.0,
                Tₗ_min=0.0,
            ),
        ),
        applications=(
            ModelSpec(Monteith(); name=:energy_balance) |>
            AppliesTo(One(scale=:Leaf)) |>
            TimeStep(Hour(1)),
            ModelSpec(Fvcb(); name=:photosynthesis) |>
            AppliesTo(One(scale=:Leaf)) |>
            TimeStep(Hour(1)),
            ModelSpec(Medlyn(0.03, 12.0); name=:stomatal_conductance) |>
            AppliesTo(One(scale=:Leaf)) |>
            TimeStep(Hour(1)),
            ModelSpec(DailyLeafSummaryTestModel(); name=:daily_summary) |>
            AppliesTo(One(scale=:Leaf)) |>
            Inputs(
                :A_integrated => One(
                    within=Self(),
                    application=:energy_balance,
                    var=:A,
                    policy=Integrate(
                        (vals, durations) -> sum(vals .* durations),
                    ),
                    window=Day(1),
                ),
                :transpiration_integrated => One(
                    within=Self(),
                    application=:energy_balance,
                    var=:λE,
                    policy=Integrate(
                        (vals, durations) -> sum(vals .* durations) / λ_ref,
                    ),
                    window=Day(1),
                ),
                :Tₗ_mean => One(
                    within=Self(),
                    application=:energy_balance,
                    var=:Tₗ,
                    policy=Aggregate(),
                    window=Day(1),
                ),
                :Tₗ_max => One(
                    within=Self(),
                    application=:energy_balance,
                    var=:Tₗ,
                    policy=Aggregate(MaxReducer()),
                    window=Day(1),
                ),
                :Tₗ_min => One(
                    within=Self(),
                    application=:energy_balance,
                    var=:Tₗ,
                    policy=Aggregate(MinReducer()),
                    window=Day(1),
                ),
            ) |>
            TimeStep(ClockSpec(24.0, 24.0)),
        ),
        environment=environment,
    )

    sim = run!(scene; steps=48, constants=Constants(), outputs=:all)
    rows = collect_outputs(sim; sink=nothing)
    energy_rows = DataFrame(
        filter(row -> row.application_id == :energy_balance, rows),
    )
    daily_rows = DataFrame(
        filter(row -> row.application_id == :daily_summary, rows),
    )
    energy = unstack(energy_rows, :timestep, :variable, :value)
    daily = unstack(daily_rows, :timestep, :variable, :value)

    @test nrow(energy) == 48
    @test daily.A_daily[1] ≈ sum(energy.A[1:24] .* 3600.0) atol = 1e-3
    @test daily.A_daily[2] ≈ sum(energy.A[25:48] .* 3600.0) atol = 1e-3
    @test !isapprox(daily.A_daily[2], daily.A_daily[1]; atol=1e-6, rtol=0.0)
    @test daily.transpiration_daily[1] ≈
          sum(energy.λE[1:24] .* 3600.0) / λ_ref atol = 1e-6
    @test daily.transpiration_daily[2] ≈
          sum(energy.λE[25:48] .* 3600.0) / λ_ref atol = 1e-6
    @test daily.Tₗ_mean_daily[1] ≈ Statistics.mean(energy.Tₗ[1:24]) atol = 1e-6
    @test daily.Tₗ_mean_daily[2] ≈ Statistics.mean(energy.Tₗ[25:48]) atol = 1e-6
    @test daily.Tₗ_max_daily[1] ≈ maximum(energy.Tₗ[1:24]) atol = 1e-6
    @test daily.Tₗ_max_daily[2] ≈ maximum(energy.Tₗ[25:48]) atol = 1e-6
    @test daily.Tₗ_min_daily[1] ≈ minimum(energy.Tₗ[1:24]) atol = 1e-6
    @test daily.Tₗ_min_daily[2] ≈ minimum(energy.Tₗ[25:48]) atol = 1e-6

    @test PlantSimEngine.timestep_hint(Monteith()).preferred == Dates.Hour(1)
end
