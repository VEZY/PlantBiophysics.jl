# First Simulation

PlantBiophysics models are ordinary PlantSimEngine model kernels. The
`leaf_scene` helper assembles a one-leaf scene and resolves their hard calls.

```@example first_simulation
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates, DataFrames

meteo = Atmosphere(
    T=22.0,
    Wind=0.8333,
    P=101.325,
    Rh=0.45,
    duration=Hour(1),
)

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
    environment=meteo,
)

simulation = run!(scene; outputs=:all)
leaf = only(model_objects(scene; scale=:Leaf))
(Tₗ=leaf.status.Tₗ, A=leaf.status.A, Gₛ=leaf.status.Gₛ)
```

The latest values remain on the leaf status. Because output retention is
explicit, the same run can also be collected as a long table:

```@example first_simulation
rows = DataFrame(collect_outputs(simulation; sink=nothing))
first(rows, 8)
```

Each row identifies its publishing application, object, timestep, variable,
and value. Continue with [Simulation over several time steps](several_simulation.md)
to advance a `Weather` series and match retained results to their input rows.
