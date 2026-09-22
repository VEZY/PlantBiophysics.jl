# Variables

This page helps you translate measurements into model inputs and interpret
simulation results. Names are case-sensitive: `T` is air temperature, while
`Tₗ` is leaf temperature.

## Common leaf variables

| Name | Meaning | Unit |
|:--|:--|:--|
| `Tₗ` | Leaf temperature | °C |
| `A` | Net CO₂ assimilation | µmol CO₂ m⁻² s⁻¹ |
| `Gₛ` | Stomatal conductance to CO₂ | mol CO₂ m⁻² s⁻¹ |
| `Cₛ`, `Cᵢ` | CO₂ concentration at the leaf surface and inside the leaf | µmol mol⁻¹ |
| `Dₗ` | Leaf-to-air vapour pressure difference | kPa |
| `aPPFD` | Absorbed photosynthetic photon flux density | µmol photons m⁻² s⁻¹ |
| `Ra_SW_f` | Absorbed shortwave radiation | W m⁻² |
| `Rn` | Net radiation | W m⁻² |
| `H`, `λE` | Sensible and latent heat fluxes | W m⁻² |
| `d` | Characteristic leaf dimension | m |

The area in these leaf-model quantities is leaf area. Canopy light models
use ground area for their radiation outputs; see
[Light interception](models/light.md) before connecting them to leaf models.
The [Micro-climate](climate/microclimate.md) page describes weather variables.

## Find the inputs and outputs of a model

A variable can be an input of one model and an output of another. For
example, a standalone Medlyn model needs assimilation `A` as an input, while
a coupled photosynthesis model calculates it.

```@example variables
using PlantBiophysics, PlantSimEngine
model = Medlyn(0.03, 12.0)
(inputs=inputs(model), outputs=outputs(model))
```

Supply the inputs that are not calculated by another model in the
simulation. The model pages describe their parameters, expected inputs, and
weather requirements; [Design](concepts/package_design.md) explains how they
fit into a simulation.

## Full variable list

Use `variables(PlantBiophysics)` to look up the package's variable names,
descriptions, and units:

```@example variables
variables(PlantBiophysics)
```
