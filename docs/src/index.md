```@meta
CurrentModule = PlantBiophysics
```

# PlantBiophysics.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/PlantBiophysics.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/PlantBiophysics.jl/dev)
[![Build Status](https://github.com/VEZY/PlantBiophysics.jl/workflows/CI/badge.svg)](https://github.com/VEZY/PlantBiophysics.jl/actions)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

## Overview

`PlantBiophysics` is a package designed to handle the biophysical processes of plants, including photosynthesis, conductances for heat, water vapor, and CO₂, latent and sensible energy fluxes, net radiation, and temperature. It supports three main use cases:

- Parameter estimation: Fit model parameters using the generic [fit](@ref PlantSimEngine.fit) function (*e.g.*, the Farquhar et al. 1980 photosynthesis model using A-Cᵢ curves).
- Model comparison: Easily compare different model implementations by providing a list of models, letting PlantBiophysics automatically couple them (*e.g.*, photosynthesis + stomatal conductance + energy balance).
- Simulation: Run fast simulations of the biophysical processes using the selected models, benefiting from the high computational performance of Julia.

The benefits of `PlantBiophysics` over existing tools are mainly:

- (very) fast yet interactive
- easily scalable: from single objects to whole scenes, one time step to many.
- easily extendable: make your own model, `PlantBiophysics` handles its coupling with others automatically
- composable: use [Unitful](https://github.com/PainterQubits/Unitful.jl) to propagate units, use [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl) to propagate measurement error

## Installation

To install the package, enter the Julia package manager mode by pressing `]` in the REPL, and execute the following command:

```julia
add PlantBiophysics
```

To use the package, execute this command from the Julia REPL:

```julia
using PlantBiophysics
```

## Examples

See the [First simulation](@ref) section for examples.

Else, here is a short example for a simulation:

```@example
using PlantBiophysics, PlantSimEngine, PlantMeteo
meteo = Atmosphere(T = 25.0, Wind = 1.0, Rh = 0.5, Ri_SW_f = 400.0) # Example meteorological data
leaf = ModelList(
        Monteith(),
        Fvcb(),
        Medlyn(0.03, 7.0),
        status = (
            Ra_SW_f = meteo[:Ri_SW_f] .* 0.8, aPPFD = meteo[:Ri_SW_f] .* 0.8 .* 0.48 .* 4.57,
            sky_fraction = 1.0, d = 0.03
        )
)
sim = run!(leaf,meteo)
```

## Similar projects

A lot of similar tools exist in the wild, pick yours from this list:

- [photosynthesis](https://github.com/cran/photosynthesis) R package
- [plantecophys](https://bitbucket.org/remkoduursma/plantecophys/src/master/) R package
- [LeafGasExchange](https://github.com/TESTgroup-BNL/LeafGasExchange) R package
- [MAESPA](http://maespa.github.io/), not really a tool, rather a model, but the implementations of the models are heavily inspired by MAESPA.

If you develop such tools and it is not on the list, please make a PR or contact me so we can add it! 😃

## Related references

Baldocchi, Dennis. 1994. « An analytical solution for coupled leaf photosynthesis and
stomatal conductance models ». Tree Physiology 14 (7-8‑9): 1069‑79.
<https://doi.org/10.1093/treephys/14.7-8-9.1069>.

Duursma, R. A., et B. E. Medlyn. 2012. « MAESPA: a model to study interactions between water
limitation, environmental drivers and vegetation function at tree and stand levels, with an
example application to [CO2] × drought interactions ». Geoscientific Model Development 5
(4): 919‑40. <https://doi.org/10.5194/gmd-5-919-2012>.

Farquhar, G. D., S. von von Caemmerer, et J. A. Berry. 1980. « A biochemical model of
photosynthetic CO2 assimilation in leaves of C3 species ». Planta 149 (1): 78‑90.

Leuning, R., F. M. Kelliher, DGG de Pury, et E.-D. SCHULZE. 1995. « Leaf nitrogen,
photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant,
Cell & Environment 18 (10): 1183‑1200.

Medlyn, B. E., D. Loustau, et S. Delzon. 2002. « Temperature response of parameters of a biochemically based model of photosynthesis. I. Seasonal changes in mature maritime pine (Pinus pinaster Ait.) ». Plant, Cell & Environment 25 (9): 1155‑65.

Medlyn, B. E., E. Dreyer, D. Ellsworth, M. Forstreuter, P. C. Harley, M. U. F. Kirschbaum, X. Le Roux, et al. 2002. « Temperature response of parameters of a biochemically based model of photosynthesis. II. A review of experimental data ». Plant, Cell & Environment 25 (9): 1167‑79. <https://doi.org/10.1046/j.1365-3040.2002.00891.x>.
