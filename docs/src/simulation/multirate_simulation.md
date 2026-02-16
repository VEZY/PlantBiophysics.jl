# Multi-rate simulation (hourly + daily)

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
- one daily model that integrates hourly assimilation

## Define a daily integration model

```@example multirate
PlantSimEngine.@process "dailyassimintegrator" verbose = false
struct DailyAssimIntegratorModel <: AbstractDailyassimintegratorModel end
PlantSimEngine.inputs_(::DailyAssimIntegratorModel) = (A = -Inf,)
PlantSimEngine.outputs_(::DailyAssimIntegratorModel) = (A_daily = -Inf,)
function PlantSimEngine.run!(::DailyAssimIntegratorModel, models, status, meteo, constants = nothing, extra = nothing)
    status.A_daily = status.A
    nothing
end
```

## Build a minimal MTG and hourly weather

```@example multirate
mtg = Node(NodeMTG("/", "Scene", 1, 0))
plant = Node(mtg, NodeMTG("+", "Plant", 1, 1))
internode = Node(plant, NodeMTG("/", "Internode", 1, 2))
Node(internode, NodeMTG("+", "Leaf", 1, 2))

meteo = Weather([
    Atmosphere(
        T = 25.0,
        Wind = 1.0,
        P = 101.3,
        Rh = 0.6,
        Cₐ = 400.0,
        Ri_SW_f = 300.0,
        duration = Dates.Hour(1)
    ) for _ in 1:48
])
```

## Configure the mapping with hourly and daily clocks

```@example multirate
mapping = ModelMapping(
    "Leaf" => (
        ModelSpec(Monteith()) |> TimeStepModel(Dates.Hour(1)),
        ModelSpec(Fvcb()) |> TimeStepModel(Dates.Hour(1)),
        ModelSpec(Medlyn(0.03, 12.0)) |> TimeStepModel(Dates.Hour(1)),
        ModelSpec(DailyAssimIntegratorModel()) |>
        TimeStepModel(Dates.Day(1)) |>
        InputBindings(; A = (process = :photosynthesis, var = :A, policy = Integrate())),
        Status(
            d = 0.03,
            Ra_SW_f = 150.0,
            sky_fraction = 1.0,
            aPPFD = 1200.0
        )
    ),
)
```

## Run and inspect outputs

```@example multirate
outs = run!(mtg, mapping, meteo, tracked_outputs = Dict{String,Any}("Leaf" => (:A, :A_daily)))
leaf_df = PlantSimEngine.convert_outputs(outs, DataFrame)["Leaf"]

first(leaf_df, 6)
```

With `TimeStepModel(Dates.Day(1))`, the daily model runs at time steps `1`, `25`, ...
and `A_daily` is then held constant between two daily updates:

```@example multirate
(leaf_df.A_daily[1], leaf_df.A_daily[24], leaf_df.A_daily[25], leaf_df.A_daily[48])
```
