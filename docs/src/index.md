```@meta
CurrentModule = PlantBiophysics
```

# PlantBiophysics.jl

PlantBiophysics provides reusable model kernels for leaf-scale biophysics:

- light interception;
- photosynthesis;
- stomatal conductance;
- energy balance.

The models run through PlantSimEngine's scene/object API and can be reused in
single-leaf, multi-organ, multi-plant, soil, and microclimate simulations.

## Quick Start

```@example home
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

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

simulation = run!(scene)
leaf = only(model_objects(scene; scale=:Leaf))
(Tₗ=leaf.status.Tₗ, A=leaf.status.A, Gₛ=leaf.status.Gₛ)
```

`leaf_scene` creates one `:Leaf` object and one model application per supplied
kernel. Hard dependencies remain explicit: `Monteith` calls photosynthesis,
and coupled photosynthesis models call stomatal conductance.

## Next Steps

- [First simulation](simulation/first_simulation.md)
- [Multi-rate simulation](simulation/multirate_simulation.md)
- [Whole-plant and multi-object scenes](simulation/mtg_simulation.md)
- [Model reference](models/photosynthesis.md)
- [Implement a model](extending/implement_a_model.md)
- [API](functions.md)
