# Hourly Leaf Calculations and Daily Summaries

Sometimes we need leaf temperature and photosynthesis every hour, but a
summary only once a day. This tutorial runs the coupled leaf model for
48 hours and produces one summary for each day:

- total net CO₂ assimilation per unit leaf area;
- transpiration expressed as a water depth;
- mean, minimum, and maximum leaf temperature.

Start with [Several time steps](several_simulation.md) if you only need models
that all run at the same interval. This page adds a small summary model to
show how calculations at different intervals can work together.

## Prepare two days of hourly weather

We keep air temperature and absorbed light constant.
Humidity and wind change within each day, and the second day is drier and
windier. These are illustrative conditions for comparing daily summaries,
not a realistic day–night light cycle.

```@example multirate
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates, DataFrames

rh_day1 = [0.75 - 0.20 * max(0.0, sin((hour - 6.0) / 12.0 * pi)) for hour in 0:23]
wind_day1 = [0.8 + 0.4 * max(0.0, sin((hour - 6.0) / 12.0 * pi)) for hour in 0:23]
Rh = vcat(rh_day1, rh_day1 .- 0.10)
Wind = vcat(wind_day1, wind_day1 .+ 0.2)

weather = Weather([
    Atmosphere(
        T=25.0, Wind=Wind[i], P=101.3, Rh=Rh[i], Cₐ=400.0,
        Ri_SW_f=300.0, duration=Hour(1),
    ) for i in 1:48
])
λ_ref = weather[1].λ
nothing # hide
```

`A` is a rate (µmol CO₂ m⁻² s⁻¹). To obtain the amount assimilated over a day,
we multiply each hourly rate by its duration in seconds, then add the amounts.
For transpiration, integrating `λE` (W m⁻²) gives energy per leaf area;
dividing by the latent heat of vaporization `λ_ref` (J kg⁻¹) gives kg m⁻²,
numerically equal to mm of water. This is water per **leaf area**, not per
ground area. Using one `λ_ref` is appropriate here because air temperature
is constant.

## Define the daily summary

The summary model simply stores the values calculated from the hourly
history. This is a small user-defined model; the
[model implementation tutorial](../extending/implement_a_model.md) explains
these declarations in detail. `Required(Real)` means that each input must
be supplied by the simulation as a real-valued number.

```@example multirate
PlantSimEngine.@process "dailyleafsummary" verbose=false
struct DailyLeafSummary <: AbstractDailyleafsummaryModel end

PlantSimEngine.inputs_(::DailyLeafSummary) = (
    A_integrated=Required(Real),
    transpiration_integrated=Required(Real),
    Tₗ_mean=Required(Real),
    Tₗ_min=Required(Real),
    Tₗ_max=Required(Real),
)
PlantSimEngine.outputs_(::DailyLeafSummary) = (
    A_daily=-Inf,
    transpiration_daily=-Inf,
    Tₗ_mean_daily=-Inf,
    Tₗ_min_daily=-Inf,
    Tₗ_max_daily=-Inf,
)
function PlantSimEngine.run!(::DailyLeafSummary, status, environment, constants, context)
    status.A_daily = status.A_integrated
    status.transpiration_daily = status.transpiration_integrated
    status.Tₗ_mean_daily = status.Tₗ_mean
    status.Tₗ_min_daily = status.Tₗ_min
    status.Tₗ_max_daily = status.Tₗ_max
    return nothing
end
```

## Connect the hourly values to the daily model

A `ModelSpec` says where and how often to use a model. The three leaf models
run every hour. The daily model reads their preceding 24 hours of results:
`Integrate` applies the duration conversions above, and `Aggregate` calculates
a mean or an extreme value.

```@example multirate
integrate_rate = Integrate((values, seconds) -> sum(values .* seconds))
integrate_water = Integrate((values, seconds) -> sum(values .* seconds) / λ_ref)

scene = CompositeModel(
    Object(:scene; status=Status(
        d=0.03, Ra_SW_f=150.0, sky_fraction=1.0, aPPFD=1200.0,
    ));
    applications=(
        ModelSpec(Monteith(); name=:energy_balance, on=One(), every=Hour(1)),
        ModelSpec(Fvcb(); name=:photosynthesis, on=One(), every=Hour(1)),
        ModelSpec(Medlyn(0.03, 12.0); name=:stomatal_conductance, on=One(), every=Hour(1)),
        ModelSpec(
            DailyLeafSummary();
            name=:daily_summary,
            on=One(),
            inputs=(
                A_integrated=One(within=Self(), application=:energy_balance,
                    var=:A, policy=integrate_rate, window=Day(1)),
                transpiration_integrated=One(within=Self(), application=:energy_balance,
                    var=:λE, policy=integrate_water, window=Day(1)),
                Tₗ_mean=One(within=Self(), application=:energy_balance,
                    var=:Tₗ, policy=Aggregate(), window=Day(1)),
                Tₗ_min=One(within=Self(), application=:energy_balance,
                    var=:Tₗ, policy=Aggregate(MinReducer()), window=Day(1)),
                Tₗ_max=One(within=Self(), application=:energy_balance,
                    var=:Tₗ, policy=Aggregate(MaxReducer()), window=Day(1)),
            ),
            every=ClockSpec(24.0, 24.0),
        ),
    ),
    environment=weather,
)
nothing # hide
```

`on=One()` applies each model to the only object in the scene, our leaf.
`Self()` selects that same leaf, and `application=:energy_balance` selects
results saved by the coupled energy-balance calculation. `window=Day(1)`
chooses the period to summarize. With an hourly base step,
`ClockSpec(24.0, 24.0)` runs the summary every 24 steps, starting at step 24.
This avoids a partial-day summary at startup. `every=Day(1)` alone would
start at step 1, then run at steps 25, 49, and so on.

!!! note "Integrating rates"

    `Integrate()` without a function adds values; it does not multiply them
    by time. Always include the duration conversion when integrating a rate.
    A time window also does not automatically align with midnight: choose
    the start of your weather series accordingly.

## Run and inspect both days

```@example multirate
simulation = run!(scene; steps=length(weather), outputs=:all)
rows = collect_outputs(simulation; sink=DataFrame)
daily_rows = subset(rows, :application_id => ByRow(==(:daily_summary)))
daily_results = unstack(
    select(daily_rows, :timestep, :variable, :value),
    :timestep, :variable, :value,
)
sort!(daily_results, :timestep)
```

The table contains one result at hour 24 and one at hour 48. `A_daily` is in
µmol CO₂ m⁻² of leaf over the day, `transpiration_daily` is in mm over the day
per leaf area, and the three temperature statistics are in °C. The different
humidity and wind conditions give different daily fluxes even though
absorbed light and air temperature stay fixed.

We can also check the first daily assimilation total directly against the
saved hourly rates:

```@example multirate
hourly_A = subset(
    rows,
    :application_id => ByRow(==(:energy_balance)),
    :variable => ByRow(==(:A)),
    :timestep => ByRow(<=(24)),
)
manual_total = sum(hourly_A.value) * 3600
@assert isapprox(daily_results.A_daily[1], manual_total)
(manual_total=manual_total, daily_model=daily_results.A_daily[1])
```

For other combinations of model intervals and history windows, see
[PlantSimEngine's time guide](https://virtualplantlab.github.io/PlantSimEngine.jl/stable/journeys/users/cadences/).
