# PlantBiophysics

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/PlantBiophysics.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/PlantBiophysics.jl/dev)
[![Build Status](https://github.com/VEZY/PlantBiophysics.jl/workflows/CI/badge.svg)](https://github.com/VEZY/PlantBiophysics.jl/actions)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

A Julia package to simulate biophysical processes for plants, such as photosynthesis, conductances for heat, water and carbon, latent and sensible energy fluxes and temperature.

## Roadmap

- [ ] Add FvCB model
- [ ] Add conductance model
- [ ] Add transpiration model
- [ ] Use structures. E.g. `Leaf`, that would be a subtype of `PhotoOrgan` (for photosynthetic organ), itself a subtype of `Organ`:
  - [ ] Make the functions compatible with an MTG, e.g. apply photosynthesis to an MTG, and use the right method for each node.
  - [ ] The `Leaf` struct would have the several fields that describe the models used for computation, with all their parameters, *e.g.*:

```julia
# Types to hold model parameter values
abstract type Model end
abstract type AModel <: Model end

struct Fvcb{T} <: AModel
 VcMax::T
 JMax::T
 Rd::T
end

abstract type GsModel <: Model end

struct Medlyn{T} <: GsModel
 g0::T
 g1::T
end

# Organs
abstract type Organ end

abstract type PhotoOrgan <: Organ end

struct Leaf{A,Gs} <: PhotoOrgan
    assimilation::A
    conductance::Gs
end

leaf = Leaf(Fvcb(10.0,50.0,3.0), Medlyn(0.033, 1.2))

photosynthesis(leaf)

function photosynthesis(leaf::Leaf)
    A = assimiliation(leaf.assimilation, leaf.conductance)
    Gs = conductance(leaf.conductance,leaf.assimilation)
    # Maybe add A as a mutable field of leaf.conductance, and
    # Gs for leaf.assimilation to keep the last record of the value
    # computed?
end

function assimiliation(A::Fvcb,Gs::GsModel)
    # Here comes the actual Fvcb model
end

function conductance(Gs::Medlyn,A::T) where T<:AModel
    # Here comes the actual conductance model from Medlyn et al. (2011)
end

function conductance(Gs::Tuzet,A::T) where T<:AModel
    # Here comes the actual conductance model from Tuzet et al. (2003)
end
```

## References

### Similar projetcs

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
