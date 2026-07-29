# Simulation Over Several Time Steps

This page runs the coupled leaf model over six hourly timesteps. It shows how
meteorology advances through a `Weather` series, how an external control loop
can update nonmeteorological drivers between steps, and how retained model
outputs map back to the input table.

```@example several_steps
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates, DataFrames

forcing = DataFrame(
    timestep=1:6,
    T=[20.0, 21.0, 23.0, 25.0, 24.0, 22.0],
    Wind=[1.0, 1.0, 1.5, 2.0, 1.5, 1.0],
    Rh=[0.65, 0.62, 0.58, 0.55, 0.58, 0.63],
    Ra_SW_f=[5.0, 10.0, 20.0, 25.0, 15.0, 5.0],
    aPPFD=[500.0, 1000.0, 1500.0, 1800.0, 1000.0, 400.0],
)

weather = Weather([
    Atmosphere(
        T=row.T,
        Wind=row.Wind,
        P=101.3,
        Rh=row.Rh,
        duration=Hour(1),
    )
    for row in eachrow(forcing)
])
first(forcing, 3)
```

The values are a compact illustrative sequence, not a calibrated experiment.
`T`, `Wind`, and `Rh` are meteorological variables, so `Weather` supplies the
appropriate row automatically at each timestep. Absorbed shortwave radiation
(`Ra_SW_f`) and absorbed photosynthetic photon flux (`aPPFD`) are externally
prescribed leaf drivers in this example.

## Assemble the leaf model

```@example several_steps
scene = leaf_scene(
    Monteith(),
    Fvcb(),
    Medlyn(0.03, 12.0);
    status=Status(
        Ra_SW_f=forcing.Ra_SW_f[1],
        sky_fraction=1.0,
        aPPFD=forcing.aPPFD[1],
        d=0.03,
    ),
    environment=weather,
)

leaf = only(model_objects(scene; scale=:Leaf))
nothing
```

A value in `Status` may itself be scalar or vector-valued, but it is one state
value and is never interpreted implicitly as a timestep series. In an
externally controlled stepping loop, update prescribed state before advancing
the simulation. For a reusable, declarative scenario, represent time-varying
forcing with an environment backend or a source application. A unique
same-object source binds automatically; use `Inputs` for cross-object, renamed,
ambiguous, or explicitly time-aggregated values.

## Run and retain the results

`run!` starts the timeline and consumes the first row of `Weather`. Subsequent
calls to `step!` preserve the environment position, scheduler state, and
retained output streams.

```@example several_steps
simulation = run!(scene; outputs=:all)

for timestep in 2:nrow(forcing)
    leaf.status.Ra_SW_f = forcing.Ra_SW_f[timestep]
    leaf.status.aPPFD = forcing.aPPFD[timestep]
    step!(simulation)
end

current_step(simulation)
```

Output retention is explicit in PlantSimEngine 0.15: the default is
`outputs=:none`. Here `outputs=:all` keeps every output published by the
energy-balance application. For a large simulation, use `OutputRequest` to
retain only the variables you need.

The latest state is always available directly on the leaf:

```@example several_steps
(Tₗ=leaf.status.Tₗ, A=leaf.status.A, Gₛ=leaf.status.Gₛ, λE=leaf.status.λE)
```

## Match outputs to input timesteps

`collect_outputs` returns a long table. Its `timestep` column uses the same
one-based scheduler steps as the input table, so the retained results can be
reshaped and joined without relying on row order:

```@example several_steps
rows = DataFrame(collect_outputs(simulation; sink=nothing))

leaf_rows = subset(
    rows,
    :application_id => ByRow(==(:energy_balance)),
    :variable => ByRow(in((:Tₗ, :A, :Gₛ, :λE))),
)

outputs_wide = unstack(
    select(leaf_rows, :timestep, :variable, :value),
    :timestep,
    :variable,
    :value,
)

results = leftjoin(forcing, outputs_wide; on=:timestep)
select(results, :timestep, :T, :Ra_SW_f, :aPPFD, :Tₗ, :A, :Gₛ, :λE)
```

The long-form representation also records the publishing application and
object. Filter by `application_id` before reshaping whenever several
applications may publish variables with the same name.
