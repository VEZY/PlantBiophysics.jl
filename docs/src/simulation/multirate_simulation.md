# Multi-rate Simulation

PlantSimEngine uses `Dates.Period` values for model cadence and temporal input
windows. The same scene can run leaf biophysics hourly and a summary model
daily.

```julia
daily = ModelSpec(DailySummary(); name=:daily_summary) |>
    AppliesTo(One(scale=:Leaf)) |>
    Inputs(
        :assimilation => One(
            within=Self(),
            application=:energy_balance,
            var=:A,
            policy=Integrate(),
            window=Day(1),
        ),
        :temperature => One(
            within=Self(),
            application=:energy_balance,
            var=:Tₗ,
            policy=Aggregate(),
            window=Day(1),
        ),
    ) |>
    TimeStep(ClockSpec(24.0, 24.0))
```

Hourly applications use `TimeStep(Hour(1))`. At compilation, PlantSimEngine
resolves the source application and creates typed temporal streams. The daily
consumer receives integrated assimilation and mean temperature without
changing either producer model.

`TimeStep(Day(1))` runs every 24 hourly steps with the default phase. Use
`ClockSpec(24.0, 24.0)` when the daily consumer should run at the end of each
24-hour window.

Available policies are `HoldLast`, `Interpolate`, `Integrate`, and `Aggregate`.
Use `MaxReducer()` or `MinReducer()` with `Aggregate` for daily extrema.

PlantBiophysics also declares timestep hints:

```@example multirate
using PlantBiophysics, PlantSimEngine, Dates
(energy=PlantSimEngine.timestep_hint(Monteith()),
 photosynthesis=PlantSimEngine.timestep_hint(Fvcb()))
```

Scenario-level `TimeStep(...)` is authoritative; hints validate whether an
inferred cadence is scientifically supported.
