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

simulation = run!(scene; steps=3, outputs=:all)
nothing # hide
```

`outputs=:all` retains the simulated values at each timestep. Display the
net radiation (`Rn`), sensible heat flux (`H`), latent heat flux (`λE`),
leaf temperature (`Tₗ`), net CO₂ assimilation (`A`), and stomatal conductance
to CO₂ (`Gₛ`) together, with one row per timestep:

```@example first_leaf
rows = DataFrame(collect_outputs(simulation; sink=nothing))
leaf_rows = subset(
    rows,
    :application_id => ByRow(==(:energy_balance)),
    :variable => ByRow(in((:Rn, :H, :λE, :Tₗ, :A, :Gₛ))),
)
outputs = unstack(
    select(leaf_rows, :timestep, :variable, :value),
    :timestep, :variable, :value,
)
select(outputs, :timestep, :Rn, :H, :λE, :Tₗ, :A, :Gₛ)
```

`Rn`, `H`, and `λE` are in W m⁻²; `Tₗ` is in °C; `A` is in
µmol CO₂ m⁻² s⁻¹; and `Gₛ` is in mol CO₂ m⁻² s⁻¹.

The latest state remains available on the leaf object:

```@example first_leaf
leaf = only(model_objects(scene; scale=:Leaf))
(
    Rn=leaf.status.Rn, H=leaf.status.H, λE=leaf.status.λE,
    Tₗ=leaf.status.Tₗ, A=leaf.status.A, Gₛ=leaf.status.Gₛ,
)
```

Continue with [Design](../concepts/package_design.md) to understand how the
models fit together, or [First simulation](../simulation/first_simulation.md)
for a step-by-step explanation.
