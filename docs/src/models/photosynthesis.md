# [Photosynthesis](@id photosynthesis_page)

Available photosynthesis implementations include:

- [`Fvcb`](@ref): analytical coupled FvCB model;
- [`FvcbIter`](@ref): iterative intercellular CO2 solution;
- [`FvcbRaw`](@ref): uncoupled FvCB equations with `Cᵢ` as input;
- [`ConstantA`](@ref) and [`ConstantAGs`](@ref): controlled-value models.

## Coupled FvCB Example

```@example photosynthesis
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

meteo = Atmosphere(
    T=25.0,
    Wind=1.0,
    P=101.3,
    Rh=0.5,
    duration=Hour(1),
)

scene = leaf_scene(
    Fvcb(),
    Medlyn(0.03, 12.0);
    status=Status(
        Tₗ=25.0,
        aPPFD=1000.0,
        Cₛ=400.0,
        Dₗ=1.5,
    ),
    environment=meteo,
)

run!(scene)
leaf = only(model_objects(scene; scale=:Leaf))
(A=leaf.status.A, Cᵢ=leaf.status.Cᵢ, Gₛ=leaf.status.Gₛ)
```

`Fvcb` declares stomatal conductance as a manual call dependency. The compiled
call can be inspected with:

```@example photosynthesis
explain_calls(PlantSimEngine.compile_composite_model(scene))
```

## Raw FvCB Example

```@example photosynthesis
raw_scene = leaf_scene(
    FvcbRaw();
    status=Status(Tₗ=25.0, aPPFD=1000.0, Cᵢ=300.0),
    environment=meteo,
)
run!(raw_scene)
only(model_objects(raw_scene; scale=:Leaf)).status.A
```

Photosynthesis models prefer an hourly timestep and accept timesteps from one
minute to six hours. Use `ModelSpec(...; every=...)` on the scenario
application when an explicit cadence is required.
