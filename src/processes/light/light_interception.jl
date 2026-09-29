@process "light_interception" """
Light interception process. Available as `object.light_interception`.

The package provides:

- `ConstantAbsorption`: fixed fractions of incident PAR and NIR, on the same surface area
- `Beer`: the Beer-Lambert law of light extinction
- `BeerShortwave`: Beer-Lambert interception for PAR and NIR

The Beer-Lambert models publish canopy radiation per unit ground area. Use
[`GroundToMeanLeafPPFD`](@ref) or [`GroundToMeanLeafShortwave`](@ref) to make
the LAI conversion explicit before leaf-scale physiology.

[`ConstantAbsorption`](@ref) can be applied directly to a leaf without `LAI`.

Geometrically explicit light interception belongs to a light package such as
ArchimedLight. Its outputs are coupled to PlantBiophysics through PlantSimEngine.

# Examples

```julia
using PlantSimEngine, PlantBiophysics, PlantMeteo
meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)
scene = CompositeModel(
    Beer(0.5);
    status=Status(LAI=2.0),
    environment=meteo,
)
run!(scene)
only(model_objects(scene)).status.aPPFD
```
""" verbose = false
