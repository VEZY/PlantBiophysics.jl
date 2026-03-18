# Multi-rate simulation (hourly leaf + daily summary)

```@setup multirate
using PlantBiophysics
using PlantBiophysics.PlantSimEngine
using PlantBiophysics.PlantMeteo
using MultiScaleTreeGraph
using DataFrames
using Dates
```

This tutorial shows how to run:

- coupled leaf energy balance + photosynthesis + stomatal conductance at hourly rate
- one daily model that summarizes hourly leaf outputs

In this example, the daily model computes:

- daily integrated assimilation (`A_daily`, `μmol m⁻² d⁻¹`)
- daily transpiration depth (`transpiration_daily`, `mm d⁻¹`)
- daily mean, max and min leaf temperature (`Tₗ_mean_daily`, `Tₗ_max_daily`, `Tₗ_min_daily`)

The daily reductions are declared explicitly in `InputBindings(...)`:

- `A` is converted from `μmol m⁻² s⁻¹` to `μmol m⁻²` using timestep durations
- `λE` is converted from `W m⁻²` to `mm` of water over the day
- `Tₗ` is summarized with mean/max/min reducers

The example keeps air temperature constant, so the latent heat of vaporization `λ` is constant too and can be reused in the transpiration reducer.

## Define the daily summary model

```@example multirate
PlantSimEngine.@process "dailyleafsummary" verbose = false
struct DailyLeafSummaryModel <: AbstractDailyleafsummaryModel end
PlantSimEngine.inputs_(::DailyLeafSummaryModel) = (
    A_integrated = -Inf,
    transpiration_integrated = -Inf,
    Tₗ_mean = -Inf,
    Tₗ_max = -Inf,
    Tₗ_min = -Inf,
)
PlantSimEngine.outputs_(::DailyLeafSummaryModel) = (
    A_daily = -Inf,
    transpiration_daily = -Inf,
    Tₗ_mean_daily = -Inf,
    Tₗ_max_daily = -Inf,
    Tₗ_min_daily = -Inf,
)
function PlantSimEngine.run!(::DailyLeafSummaryModel, models, status, meteo, constants = nothing, extra = nothing)
    status.A_daily = status.A_integrated
    status.transpiration_daily = status.transpiration_integrated
    status.Tₗ_mean_daily = status.Tₗ_mean
    status.Tₗ_max_daily = status.Tₗ_max
    status.Tₗ_min_daily = status.Tₗ_min
    nothing
end
```

## Build a minimal MTG and hourly weather

We use two days of hourly weather. The absorbed radiation remains fixed in the leaf status, while the humidity and wind profiles differ between the two days.

```@example multirate
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
        T = 25.0,
        Wind = Wind[i],
        P = 101.3,
        Rh = Rh[i],
        Cₐ = 400.0,
        Ri_SW_f = 300.0,
        duration = Dates.Hour(1)
    ) for i in 1:48
])
λ_ref = meteo[1].λ
```

## Configure the mapping with hourly and daily clocks

```@example multirate
mapping = ModelMapping(
    :Leaf => (
        Monteith(),
        Fvcb(),
        Medlyn(0.03, 12.0),
        ModelSpec(DailyLeafSummaryModel()) |>
        TimeStepModel(ClockSpec(24.0, 0.0)) |>
        InputBindings(
            ;
            A_integrated = (process = :energy_balance, var = :A, policy = Integrate((vals, durations) -> sum(vals .* durations))),
            transpiration_integrated = (process = :energy_balance, var = :λE, policy = Integrate((vals, durations) -> sum(vals .* durations) / λ_ref)),
            Tₗ_mean = (process = :energy_balance, var = :Tₗ, policy = Aggregate()),
            Tₗ_max = (process = :energy_balance, var = :Tₗ, policy = Aggregate(MaxReducer())),
            Tₗ_min = (process = :energy_balance, var = :Tₗ, policy = Aggregate(MinReducer())),
        ),
        Status(
            d = 0.03,
            Ra_SW_f = 150.0,
            sky_fraction = 1.0,
            aPPFD = 1200.0,
            A_integrated = 0.0,
            transpiration_integrated = 0.0,
            Tₗ_mean = 0.0,
            Tₗ_max = 0.0,
            Tₗ_min = 0.0,
        )
    ),
)
```

## Run and inspect outputs

```@example multirate
outs = run!(
    mtg,
    mapping,
    meteo,
    tracked_outputs = Dict{Symbol,Any}(
        :Leaf => (
            :A,
            :λE,
            :Tₗ,
            :A_daily,
            :transpiration_daily,
            :Tₗ_mean_daily,
            :Tₗ_max_daily,
            :Tₗ_min_daily,
        )
    )
)
leaf_df = PlantSimEngine.convert_outputs(outs, DataFrame)[:Leaf]

leaf_df[[24, 48], [:A_daily, :transpiration_daily, :Tₗ_mean_daily, :Tₗ_max_daily, :Tₗ_min_daily]]
```

The two days have different humidity and wind profiles, so the daily summaries are different too:

```@example multirate
!isapprox(leaf_df.A_daily[48], leaf_df.A_daily[24]; atol = 1e-6) &&
!isapprox(leaf_df.transpiration_daily[48], leaf_df.transpiration_daily[24]; atol = 1e-9)
```

The daily temperature summary behaves as expected too:

```@example multirate
all(leaf_df.Tₗ_min_daily[[24, 48]] .< leaf_df.Tₗ_mean_daily[[24, 48]]) &&
all(leaf_df.Tₗ_mean_daily[[24, 48]] .< leaf_df.Tₗ_max_daily[[24, 48]])
```

With `ClockSpec(24.0, 0.0)`, the daily model runs at the end of each day (`t = 24, 48, ...`).
