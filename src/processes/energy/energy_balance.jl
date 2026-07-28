# Generate all methods for the energy_balance process: several meteo time-steps, components,
#  over an MTG, and the mutating /non-mutating versions
@process "energy_balance" """
Energy balance process. This process computes the energy balance of objects, 
meaning that it computes the net radiation, the sensible heat flux, and the 
latent heat flux if necessary. It can be coupled with a photosynthesis 
model in the case of plants leaves.

At the moment, two models are implemented in the package:

- `Monteith`: the model found in Monteith and Unsworth (2013)
- `Missing`: if no computation of the energy balance is needed

# Note

Some models need input values for variables not produced by another application.
For example, `Monteith` requires `Ra_SW_f`, `d`, and `sky_fraction`.

# Examples

```julia
using PlantMeteo, PlantSimEngine, PlantBiophysics

meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
scene = leaf_scene(
    Monteith(),
    Fvcb(),
    Medlyn(0.03, 12.0);
    status=Status(Ra_SW_f=13.747, sky_fraction=1.0, aPPFD=1500.0, d=0.03),
    environment=meteo,
)
run!(scene)
leaf = only(model_objects(scene; scale=:Leaf))
(leaf.status.Rn, leaf.status.A, leaf.status.Cᵢ)
```

# References

Duursma, R. A., et B. E. Medlyn. 2012. « MAESPA: a model to study interactions between water
limitation, environmental drivers and vegetation function at tree and stand levels, with an
example application to [CO2] × drought interactions ». Geoscientific Model Development 5 (4):
919‑40. https://doi.org/10.5194/gmd-5-919-2012.

Monteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i)
Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition),
edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.

Schymanski, Stanislaus J., et Dani Or. 2017. « Leaf-Scale Experiments Reveal an Important
Omission in the Penman–Monteith Equation ». Hydrology and Earth System Sciences 21 (2): 685‑706.
https://doi.org/10.5194/hess-21-685-2017.

Vezy, Rémi, Mathias Christina, Olivier Roupsard, Yann Nouvellon, Remko Duursma, Belinda Medlyn,
Maxime Soma, et al. 2018. « Measuring and modelling energy partitioning in canopies of varying
complexity using MAESPA model ». Agricultural and Forest Meteorology 253‑254 (printemps): 203‑17.
https://doi.org/10.1016/j.agrformet.2018.02.005.
""" verbose = false
