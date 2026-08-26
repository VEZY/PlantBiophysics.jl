@process "light_interception" """
Light interception process. Available as `object.light_interception`.

Two Beer-Lambert models are implemented in the package:

- `Beer`: the Beer-Lambert law of light extinction
- `BeerShortwave`: Beer-Lambert interception for PAR and NIR

Geometrically explicit light interception belongs to a light package such as
ArchimedLight. Its outputs are coupled to PlantBiophysics through PlantSimEngine.

# Examples

```julia
using PlantSimEngine, PlantBiophysics, PlantMeteo
meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)
scene = leaf_scene(Beer(0.5); status=Status(LAI=2.0), environment=meteo)
run!(scene)
only(model_objects(scene; scale=:Leaf)).status.aPPFD
```
""" verbose = false
