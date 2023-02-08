@process "light_interception" """
Light interception process. Available as `object.light_interception`.

At the moment, two models are implemented in the package:

- `Beer`: the Beer-Lambert law of ligth extinction
- `LightIgnore`: ignore the computation of light interception (this one is for backward
compatibility with ARCHIMED-ϕ)

# Examples

```julia
using PlantSimEngine, PlantBiophysics, PlantMeteo
m = ModelList(light_interception=Beer(0.5), status=(LAI=2.0,))

meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)

run!(m, meteo)

m[:PPFD]
```
"""