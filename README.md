# PlantBiophysics

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/PlantBiophysics.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/PlantBiophysics.jl/dev)
[![Build Status](https://github.com/VEZY/PlantBiophysics.jl/workflows/CI/badge.svg)](https://github.com/VEZY/PlantBiophysics.jl/actions)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

A Julia package to simulate biophysical processes for plants, such as photosynthesis, conductances for heat, water and carbon, latent and sensible energy fluxes and temperature.

## Roadmap

- [ ] Add FvCB model
- [ ] Add FvCB iterative model. Check the 1.0e-6 in `Cₛ = min(environment.Cₐ, environment.Cₐ - A * 1.0e-6 / Gₛ)`
- [ ] Add conductance model
- [ ] Add transpiration model
- [ ] Use structures. E.g. `Leaf`, that would be a subtype of `PhotoOrgan` (for photosynthetic organ), itself a subtype of `Organ`:
  - [ ] Make the functions compatible with an MTG, e.g. apply photosynthesis to an MTG, and use the right method for each node.
  - [ ] The `Leaf` struct would have the several fields that describe the models used for computation, with all their parameters, *e.g.*:

### Notes

The Fvcb model is implemented in two ways:

- as in MAESPA, where the model needs Cₛ as input. And Cₛ is computed in the energy balance model and helps to close the whole balance with leaf temperature. If needed, Cₛ can be given as Cₐ.
- as in Archimed, where the model needs gbc, but not Cₛ (and Cₐ instead) because the model iterates over the assimilation until it finds a stable Cᵢ. This implementation
can be less efficient because of the iterations.

## References

### Similar projects

- [MAESPA](http://maespa.github.io/)
- [photosynthesis](https://github.com/cran/photosynthesis) R package
- [plantecophys](https://bitbucket.org/remkoduursma/plantecophys/src/master/) R package
Leuning et al. (1995)
- [LeafGasExchange](https://github.com/TESTgroup-BNL/LeafGasExchange) R package

### Scientific references

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
