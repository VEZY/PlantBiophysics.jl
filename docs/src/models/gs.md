# [Stomatal Conductance](@id gs_page)

The stomatal conductance process computes conductance to CO2 (`Gₛ`). Available
implementations are:

- [`Medlyn`](@ref);
- [`Tuzet`](@ref);
- [`ConstantGs`](@ref).

## Standalone Model

```@example gs
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

meteo = Atmosphere(
    T=25.0,
    Wind=1.0,
    P=101.3,
    Rh=0.5,
    duration=Hour(1),
)

scene = leaf_scene(
    Medlyn(0.03, 12.0);
    status=Status(A=20.0, Cₛ=400.0, Dₗ=1.5),
    environment=meteo,
)

run!(scene)
only(model_objects(scene; scale=:Leaf)).status.Gₛ
```

## Timestep Contract

Stomatal conductance models declare a required range of one minute to six hours
and prefer one hour:

```@example gs
PlantSimEngine.timestep_hint(Medlyn(0.03, 12.0))
```

A scenario can override the cadence:

```@example gs
spec = ModelSpec(Medlyn(0.03, 12.0); on=One(scale=:Leaf), every=Hour(3))
spec.timestep
```

## Tuzet Water Stress

[`Tuzet`](@ref) adds leaf water potential (`Ψₗ`) to the conductance response.
Its parameters control the potential at half closure and the steepness of the
closure response.

```@example gs
tuzet_scene = leaf_scene(
    Tuzet(0.03, 12.0, -1.5, 2.0, 30.0);
    status=Status(A=20.0, Cₛ=400.0, Ψₗ=-1.0),
    environment=meteo,
)
run!(tuzet_scene)
only(model_objects(tuzet_scene; scale=:Leaf)).status.Gₛ
```

Use `inputs(model)` and `outputs(model)` to inspect each model's variable
contract.
