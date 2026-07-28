# First Simulation

PlantBiophysics models are ordinary PlantSimEngine model kernels. The
`leaf_scene` helper assembles a one-leaf scene and resolves their hard calls.

```@example simulation
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates, DataFrames

weather = Weather([
    Atmosphere(
        T=20.0 + 0.5 * hour,
        Wind=1.0,
        P=101.3,
        Rh=0.65,
        duration=Hour(1),
    )
    for hour in 0:5
])

scene = leaf_scene(
    Monteith(),
    Fvcb(),
    Medlyn(0.03, 12.0);
    status=Status(
        Ra_SW_f=13.747,
        sky_fraction=1.0,
        aPPFD=1500.0,
        d=0.03,
    ),
    environment=weather,
)

simulation = run!(scene; steps=6);
nothing
```

Inspect the latest state directly:

```@example simulation
leaf = only(model_objects(scene; scale=:Leaf))
(Tₗ=leaf.status.Tₗ, A=leaf.status.A, Gₛ=leaf.status.Gₛ)
```

Or collect retained output streams:

```@example simulation
rows = DataFrame(collect_outputs(simulation; sink=nothing))
first(rows, 8)
```

The long-form table identifies the publishing application, object, timestep,
variable, and value. Filter by `application_id` before reshaping when several
applications publish related variables.
