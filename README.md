# PlantBiophysics

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/PlantBiophysics.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/PlantBiophysics.jl/dev)
[![Build Status](https://github.com/VEZY/PlantBiophysics.jl/workflows/CI/badge.svg)](https://github.com/VEZY/PlantBiophysics.jl/actions)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

A Julia package to simulate biophysical processes for plants such as photosynthesis, conductances for heat, water vapor and CO₂, latent, sensible energy fluxes, net radiation and temperature.

## Examples

Here is an example usage with a simulation of the energy balance and assimilation of a leaf:

```julia
using PlantBiophysics

# Declaring the meteorology for the simulated time-step:
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

# Using the model from Medlyn et al. (2011) for Gs and the model of Monteith and Unsworth (2013) for the
# energy balance:
leaf = Leaf(geometry = Geom1D(0.03),
            energy = Monteith(),
            photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            Rn = 13.747, skyFraction = 1.0, PPFD = 1500.0)

energy_balance(leaf,meteo)
```

For more examples, please read the documentation.
## Roadmap

- [x] Add FvCB model
- [x] Add FvCB iterative model
- [x] Add stomatal + boundary layer conductance models
- [x] Add energy balance model, coupled with photosynthesis amd stomatal conductance models
- [ ] Make the functions compatible with an MTG, e.g. apply photosynthesis to an MTG, and use the right method for each node. NB: I think the models should be a field of the node.
- [ ] Make the functions compatible with several meteorological time-steps
- [ ] Evaluate using Schymanski et al. (2017) data + leaf measurements models.
- [ ] Add more documentation + tutorial:
  - [ ] add doc about the design (components, models, model values, multiple dispatch)
  - [ ] add doc about input files
  - [ ] add doc for each process
  - [ ] add a list of models for each process
  - [ ] add documentation for each model
  - [ ] add a tutorial for a single leaf at one time-step
  - [ ] add a tutorial for a single leaf at several time-step
  - [ ] add a tutorial for a plant
  - [ ] How to implement a new model -> e.g. conductance
  - [ ] How to implement a new component -> modify `get_componenttype()` + add methods to functions eventually

### Notes

The Fvcb model is implemented in two ways:

- as in MAESPA, where the model needs Cₛ as input. And Cₛ is computed in the energy balance model and helps to close the whole balance with leaf temperature. If needed, Cₛ can be given as Cₐ.
- as in Archimed, where the model needs Gbc, but not Cₛ (and Cₐ instead) because the model iterates over the assimilation until it finds a stable Cᵢ. This implementation
can be less efficient because of the iterations.

## Similar projects

- [MAESPA](http://maespa.github.io/)
- [photosynthesis](https://github.com/cran/photosynthesis) R package
- [plantecophys](https://bitbucket.org/remkoduursma/plantecophys/src/master/) R package
Leuning et al. (1995)
- [LeafGasExchange](https://github.com/TESTgroup-BNL/LeafGasExchange) R package

## References

Baldocchi, Dennis. 1994. « An analytical solution for coupled leaf photosynthesis and
stomatal conductance models ». Tree Physiology 14 (7-8‑9): 1069‑79.
https://doi.org/10.1093/treephys/14.7-8-9.1069.

Duursma, R. A., et B. E. Medlyn. 2012. « MAESPA: a model to study interactions between water
limitation, environmental drivers and vegetation function at tree and stand levels, with an
example application to [CO2] × drought interactions ». Geoscientific Model Development 5
(4): 919‑40. https://doi.org/10.5194/gmd-5-919-2012.

Farquhar, G. D., S. von von Caemmerer, et J. A. Berry. 1980. « A biochemical model of
photosynthetic CO2 assimilation in leaves of C3 species ». Planta 149 (1): 78‑90.

Leuning, R., F. M. Kelliher, DGG de Pury, et E.-D. SCHULZE. 1995. « Leaf nitrogen,
photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant,
Cell & Environment 18 (10): 1183‑1200.

Medlyn, B. E., D. Loustau, et S. Delzon. 2002. « Temperature response of parameters of a biochemically based model of photosynthesis. I. Seasonal changes in mature maritime pine (Pinus pinaster Ait.) ». Plant, Cell & Environment 25 (9): 1155‑65.

Medlyn, B. E., E. Dreyer, D. Ellsworth, M. Forstreuter, P. C. Harley, M. U. F. Kirschbaum, X. Le Roux, et al. 2002. « Temperature response of parameters of a biochemically based model of photosynthesis. II. A review of experimental data ». Plant, Cell & Environment 25 (9): 1167‑79. https://doi.org/10.1046/j.1365-3040.2002.00891.x.
