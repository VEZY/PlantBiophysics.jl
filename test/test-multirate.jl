using Statistics

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
function PlantSimEngine.run!(::DailyLeafSummaryTestModel, models, status, meteo, constants=nothing, extra=nothing)
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

    meteo = Weather([
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

    λ_ref = meteo[1].λ

    mapping = ModelMapping(
        :Leaf => (
            Monteith(),
            Fvcb(),
            Medlyn(0.03, 12.0),
            ModelSpec(DailyLeafSummaryTestModel()) |>
            TimeStepModel(ClockSpec(24.0, 0.0)) |>
            InputBindings(
                ;
                A_integrated=(process=:energy_balance, var=:A, policy=Integrate((vals, durations) -> sum(vals .* durations))),
                transpiration_integrated=(process=:energy_balance, var=:λE, policy=Integrate((vals, durations) -> sum(vals .* durations) / λ_ref)),
                Tₗ_mean=(process=:energy_balance, var=:Tₗ, policy=Aggregate()),
                Tₗ_max=(process=:energy_balance, var=:Tₗ, policy=Aggregate(MaxReducer())),
                Tₗ_min=(process=:energy_balance, var=:Tₗ, policy=Aggregate(MinReducer())),
            ),
            Status(
                d=0.03,
                Ra_SW_f=150.0,
                sky_fraction=1.0,
                aPPFD=1200.0,
                A_integrated=0.0,
                transpiration_integrated=0.0,
                Tₗ_mean=0.0,
                Tₗ_max=0.0,
                Tₗ_min=0.0,
            )
        ),
    )

    out = run!(
        mtg,
        mapping,
        meteo,
        tracked_outputs=Dict(
            :Leaf => (:A, :λE, :Tₗ, :A_daily, :transpiration_daily, :Tₗ_mean_daily, :Tₗ_max_daily, :Tₗ_min_daily)
        ),
        executor=SequentialEx(),
    )
    out_df = convert_outputs(out, DataFrame)[:Leaf]

    @test nrow(out_df) == 48
    @test all(out_df.A_daily[24:47] .== out_df.A_daily[24])
    @test out_df.A_daily[24] ≈ sum(out_df.A[1:24] .* 3600.0) atol = 1e-3
    @test out_df.A_daily[48] ≈ sum(out_df.A[25:48] .* 3600.0) atol = 1e-3
    @test !isapprox(out_df.A_daily[48], out_df.A_daily[24]; atol=1e-6, rtol=0.0)

    @test all(out_df.transpiration_daily[24:47] .== out_df.transpiration_daily[24])
    @test out_df.transpiration_daily[24] ≈ sum(out_df.λE[1:24] .* 3600.0) / λ_ref atol = 1e-6
    @test out_df.transpiration_daily[48] ≈ sum(out_df.λE[25:48] .* 3600.0) / λ_ref atol = 1e-6
    @test !isapprox(out_df.transpiration_daily[48], out_df.transpiration_daily[24]; atol=1e-9, rtol=0.0)

    @test out_df.Tₗ_mean_daily[24] ≈ Statistics.mean(out_df.Tₗ[1:24]) atol = 1e-6
    @test out_df.Tₗ_mean_daily[48] ≈ Statistics.mean(out_df.Tₗ[25:48]) atol = 1e-6
    @test out_df.Tₗ_max_daily[24] ≈ maximum(out_df.Tₗ[1:24]) atol = 1e-6
    @test out_df.Tₗ_max_daily[48] ≈ maximum(out_df.Tₗ[25:48]) atol = 1e-6
    @test out_df.Tₗ_min_daily[24] ≈ minimum(out_df.Tₗ[1:24]) atol = 1e-6
    @test out_df.Tₗ_min_daily[48] ≈ minimum(out_df.Tₗ[25:48]) atol = 1e-6
    @test out_df.Tₗ_min_daily[24] < out_df.Tₗ_mean_daily[24] < out_df.Tₗ_max_daily[24]
    @test out_df.Tₗ_min_daily[48] < out_df.Tₗ_mean_daily[48] < out_df.Tₗ_max_daily[48]

    @test PlantSimEngine.timestep_hint(Monteith()).preferred == Dates.Hour(1)
end
