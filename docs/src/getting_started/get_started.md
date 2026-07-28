# First Leaf Simulation

This is the shortest path to a coupled leaf energy-balance simulation.

```@example first_leaf
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates, DataFrames

meteo = Weather([
    Atmosphere(
        T=20.0 + hour / 10,
        Wind=1.0,
        P=101.3,
        Rh=0.65,
        duration=Hour(1),
    )
    for hour in 1:3
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
    environment=meteo,
)

simulation = run!(scene; steps=3)
outputs = DataFrame(collect_outputs(simulation; sink=nothing))
first(outputs, 6)
```

The latest state remains available on the leaf object:

```@example first_leaf
leaf = only(model_objects(scene; scale=:Leaf))
(Tₗ=leaf.status.Tₗ, A=leaf.status.A, λE=leaf.status.λE)
```

Use `explain_calls(compile_composite_model(scene))` to inspect the manually controlled
energy-balance call stack.
