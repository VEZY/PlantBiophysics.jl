# Simulation Over Several Time Steps

After the [one-timestep example](first_simulation.md), let's simulate a leaf
over six hours. A simple light model absorbs a fixed fraction of the incoming
radiation at each hour. We will run the whole weather series in one call,
collect the results, and plot the leaf's response.

## Prepare the input table

`Weather` is a sequence of `Atmosphere` values, one for each timestep. Here we
create it from a small table; you can also import measured weather as shown
on the [Micro-climate](../climate/microclimate.md) page.

```@example several_steps
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates, DataFrames

forcing = DataFrame(
    timestep=1:6,
    T=[20.0, 21.0, 23.0, 25.0, 24.0, 22.0],
    Wind=[1.0, 1.0, 1.5, 2.0, 1.5, 1.0],
    Rh=[0.65, 0.62, 0.58, 0.55, 0.58, 0.63],
    Ri_PAR_f=[100.0, 200.0, 300.0, 360.0, 200.0, 80.0],
    Ri_NIR_f=[120.0, 240.0, 360.0, 430.0, 240.0, 100.0],
    P=fill(101.3, 6),
    duration=fill(Hour(1), 6)
)

weather = Weather(forcing)
first(forcing, 3)
```

`Weather` supplies the appropriate row automatically at each timestep.
`Ri_PAR_f` and `Ri_NIR_f` are incoming photosynthetically active and near-infrared
radiation arriving at the leaf, both in W m⁻² of leaf area. The light model
will calculate how much of this radiation the leaf absorbs.

The other units are °C for `T`, m s⁻¹ for `Wind`, and kPa for `P`.
`Rh` is a fraction, not a percentage. These values describe an illustrative
six-hour weather sequence.

## Assemble the leaf model

Add [`ConstantAbsorption`](@ref) to the same leaf model as before. Here it
absorbs 80% of incoming PAR and 20% of incoming NIR. These are illustrative
fractions; choose values appropriate for your leaf and light source.

```@example several_steps
scene = CompositeModel(
    ConstantAbsorption(α_PAR=0.8, α_NIR=0.2),
    Monteith(),
    Fvcb(),
    Medlyn(0.03, 12.0);
    status=Status(sky_fraction=1.0, d=0.03),
    environment=weather,
)
nothing # hide
```

`ConstantAbsorption` supplies `aPPFD` to photosynthesis and `Ra_SW_f` to
energy balance automatically. The fractions stay constant, but the absorbed
radiation changes with each weather row. No `LAI` or manual radiation update
is needed. See [Light interception](../models/light.md) for the equations and
an example with controlled lighting.

## Run and retain the results

Pass the number of weather records to `run!` to simulate all six hours.
PlantSimEngine recalculates light interception and the leaf response at each
step, so there is no need to update radiation values by hand.

```@example several_steps
simulation = run!(scene; steps=length(weather), outputs=:all)
current_step(simulation)
```

`outputs=:all` saves the calculated values at every step; the default
`outputs=:none` only leaves the latest values on the objects.

The latest state is always available directly on the leaf:

```@example several_steps
leaf = only(model_objects(scene))
(Tₗ=leaf.status.Tₗ, A=leaf.status.A, Gₛ=leaf.status.Gₛ, λE=leaf.status.λE)
```

And more generally, `collect_outputs` returns a long-form table of all recorded variables that were requested in `run!`. Each row corresponds to a single variable, object, application, and timestep:

```@example several_steps
sim_long_form = collect_outputs(simulation; sink=DataFrame)

first(sim_long_form, 3) # Only showing the first three rows for brevity
```

## Match outputs to input timesteps

We can turn the long-form representation into a wide table with one row per timestep using `unstack`.
Then we can join the meteorological data with the simulation results using `leftjoin`. This puts
the inputs and results in the same table. We use `timestep` to match each
result to its input row.

!!! note
    Requiring all variables as outputs makes a slower simulation. If you only need a few variables, request them explicitly in `run!` to speed up the calculation. Else, you can filter the long-form table after the simulation to keep only the variables you need using `subset`.

```@example several_steps

# Selecting only the variables we need:
df_long_form_few = subset(
    sim_long_form,
    :variable => ByRow(in((:Tₗ, :A, :Gₛ, :λE))),
)

df_wide = unstack(
    select(df_long_form_few, :timestep, :variable, :value),
    :timestep,
    :variable,
    :value,
)

# Joining the weather and simulation results:
df = leftjoin(forcing, df_wide; on=:timestep)
# Selecting only the variables we need:
select(df, :timestep, :T, :Ri_PAR_f, :Ri_NIR_f, :Tₗ, :A, :Gₛ, :λE)
```

The long-form representation also records the publishing application and
object. Filter by `application_id` before reshaping whenever several
applications may publish variables with the same name.

## Plot the leaf response

The first panel compares leaf and air temperature. The second shows how net
assimilation changes with the supplied weather and light.

```@example several_steps
using CairoMakie

figure = Figure(size=(800, 330))
temperature_axis = Axis(figure[1, 1]; xlabel="Timestep (hour)", ylabel="Temperature (°C)")
lines!(temperature_axis, df.timestep, df.T; label="Air")
lines!(temperature_axis, df.timestep, Float64.(df.Tₗ); label="Leaf")
axislegend(temperature_axis; position=:lt)

assimilation_axis = Axis(figure[1, 2]; xlabel="Timestep (hour)", ylabel="A (µmol CO₂ m⁻² s⁻¹)")
scatterlines!(assimilation_axis, df.timestep, Float64.(df.A))
figure
```

Continue with [Several objects](several_objects_simulation.md) to compare
leaves receiving different amounts of light.
