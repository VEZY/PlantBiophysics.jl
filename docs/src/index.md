```@meta
CurrentModule = PlantBiophysics
```

# PlantBiophysics.jl

PlantBiophysics is a Julia package for simulating photosynthesis, stomatal
conductance, leaf temperature, and exchanges of heat and water. It also
provides simple canopy light-interception models.

You can [run a leaf simulation](getting_started/get_started.md),
[fit model parameters to measurements](getting_started/first_fit.md),
[compare photosynthesis models](models/photosynthesis.md), or
[propagate uncertainty in your inputs](simulation/uncertainty_propagation.md).
The models run together through PlantSimEngine and can be applied to one
leaf, several organs, or a whole plant.

If you are new to the package, the [Design page](concepts/package_design.md)
introduces processes, models, parameters, and simulation inputs.

## Installation

In the Julia REPL, press `]` to enter package mode, then install the packages
used in the examples:

```text
pkg> add PlantBiophysics PlantSimEngine PlantMeteo
```

Press Backspace to return to the Julia prompt.

## Quick Start

This example combines an energy-balance model (`Monteith`), a photosynthesis
model (`Fvcb`), and a stomatal-conductance model (`Medlyn`) for one leaf.
The input values are illustrative.

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

`leaf_scene` brings the models, leaf inputs, and weather together. `run!`
calculates their results, which remain available on the leaf's `status`.
The values shown are leaf temperature (`Tₗ`, °C), net CO₂ assimilation
(`A`, µmol CO₂ m⁻² s⁻¹), and stomatal conductance to CO₂
(`Gₛ`, mol CO₂ m⁻² s⁻¹).

## Next Steps

- [First simulation](simulation/first_simulation.md): understand each step.
- [Several time steps](simulation/several_simulation.md): use changing weather
  and collect a table of results.
- [Models](models/photosynthesis.md): choose equations and parameters.
- [Model evaluation](evaluation.md): compare simulations with measurements.
- [Whole-plant simulation](simulation/mtg_simulation.md): apply models to organs.
- [Implement a model](extending/implement_a_model.md): add your own equations.
- [API reference](functions.md): look up individual functions.
