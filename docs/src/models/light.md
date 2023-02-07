# [Light interception](@id light_page)

```@setup usepkg
using PlantBiophysics, PlantSimEngine
```

The light interception process is the process of computing the radiation interception of components for different wavelength such as PAR (Photosynthetically Active Radication), NIR (Near-Infrared Radiation) and eventually TIR (Thermal Infrared Radiation). Users can also compute particular wavelengths (*e.g.* red, far-red) depending on the model used.

There is only one simple light interception model implemented in PlantBiophysics at the time, the model of Beer-Lambert. Here's an example:

```@example usepkg
using PlantBiophysics, PlantSimEngine

m = ModelList(light_interception=Beer(0.5), status=(LAI=2.0,))

meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)

run!(m, meteo)

m
```

!!! note
    If you have a 3D plant in the OPF format, you can use [Archimed-ϕ](https://archimed-platform.github.io/archimed-phys-user-doc/).
