"""
    energy_balance(meteo::Atmosphere,leaf::PhotoComponent,constants)
    energy_balance(meteo::Atmosphere,leaf::PhotoComponent)

Energy balance of the object.

# Arguments

- `Tₐ` (°C): air temperature
- `Wind` (m s-1): wind speed
- `Rh` (0-1): air relative humidity
- `Rn` (W m-2): net radiation
- `Rsᵥ` (s m-1): stomatal resistance to water vapor
- `P` (kPa): air pressure
- `d` (m): characteristic dimension, *e.g.* leaf width (`d` in eq. 10.9 from Monteith and Unsworth, 2013).
- `Dheat` (m s-1): molecular diffusivity for heat
- `maxiter::Int`: maximum number of iterations
- `adjustrn::Bool`: adjust the Rn value for longwave emission after re-computing the leaf temperature?
- `hypostomatous::Bool`: is the leaf hypostomatous?
- `skyFraction` (0-2): fraction of sky viewed by the leaf.


# Note

The skyFraction is equal to 2 if all the leaf is viewing is sky (e.g. in a controlled chamber), 1
if the leaf is *e.g.* up on the canopy where the upper side of the leaf sees the sky, and the
side bellow sees soil + other leaves that are all considered at the same temperature than the leaf,
or less than 1 if it is partly shaded.

`d` is the minimal dimension of the surface of an object in contact with the air.

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
energy_balance(meteo,Constants())
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
"""
function energy_balance(object::PhotoComponent,meteo::Atmosphere,constants)
    net_radiation(object.energy, object.photosynthesis, object.stomatal_conductance, meteo, constants)
end

function energy_balance(object::PhotoComponent,meteo::Atmosphere)
    constants = Constants()
    net_radiation(object.energy, object.photosynthesis, object.stomatal_conductance, meteo, constants)
end
