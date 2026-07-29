# PlantBiophysics

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/PlantBiophysics.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/PlantBiophysics.jl/dev)
[![Build Status](https://github.com/VEZY/PlantBiophysics.jl/workflows/CI/badge.svg)](https://github.com/VEZY/PlantBiophysics.jl/actions)

PlantBiophysics provides reusable Julia models for leaf light interception,
photosynthesis, stomatal conductance, and energy balance. Models implement the
PlantSimEngine kernel contract and can be assembled on one leaf or inside
larger multi-plant scenes.

## Installation

```julia
using Pkg
Pkg.add("PlantBiophysics")
```

## One-leaf simulation

```julia
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
(temperature=leaf.status.Tₗ, assimilation=leaf.status.A)
```

`leaf_scene` is a convenience constructor. The returned value is an ordinary
`PlantSimEngine.CompositeModel`, so applications can also be assembled explicitly with
`ModelSpec`, `AppliesTo`, `Inputs`, `Calls`, and `TimeStep`.

PlantBiophysics models preserve generic numeric types, which supports units,
automatic differentiation, and uncertainty propagation when the supplied
operations support those types.

## Development with PlantSimEngine

Until PlantSimEngine 0.15 is released, check out its `multi-plants` branch
wherever you keep development packages, then point the PlantBiophysics
environment to that working tree:

```julia-repl
pkg> activate .
pkg> develop /path/to/PlantSimEngine
pkg> test
```

`Pkg.develop` records the working-tree path only in the local `Manifest.toml`;
the repository does not assume where PlantSimEngine is cloned. Once a
compatible PlantSimEngine release is available, run `free` in each environment
where it was developed:

```julia-repl
pkg> free PlantSimEngine
```

The documentation uses the same workflow:

```julia-repl
pkg> activate docs
pkg> develop /path/to/PlantSimEngine
pkg> instantiate
```

Then build it with `julia --project=docs docs/make.jl`.

## Questions

Use the [issue tracker](https://github.com/VEZY/PlantBiophysics.jl/issues) or
the [Virtual Plant Lab forum](https://fspm.discourse.group/c/software/virtual-plant-lab).
