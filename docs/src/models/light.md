# [Light interception](@id light_page)

```@setup usepkg
using PlantBiophysics, PlantSimEngine
```

The light interception process is the process of computing the radiation interception of components for different wavelength such as PAR (Photosynthetically Active Radication), NIR (Near-Infrared Radiation) and eventually TIR (Thermal Infrared Radiation). Users can also compute particular wavelengths (*e.g.* red, far-red) depending on the model used.

There are two light interception models implemented in PlantBiophysics at the time, both derived from the Beer-Lambert law of light extinction. 

- [Beer model](@ref beer): The first one is the Beer model, which is a simple model that computes the light interception (`PPFD`) of a component as a function of the leaf area index (`LAI`) and the extinction coefficient (`k`). The Beer model is implemented in the `Beer` type. This model is recommended if you need to compute the photosynthesis of the plant, but not the energy balance.

- [Beer model with shortwave radiation](@ref beer_shortwave): the second one is the same model as the `Beer` model, but with a computation of the intercepted shortwave radiation (`Rₛ`) added to the computation of the `PPFD`. This model needs the `k` coefficient, and the `f` coefficient, which is a proportionality factor between the shortwave radiation and the PPFD (usually 0.48, the default).
This model is recommended if you need to compute the energy balance of the object. The model is implemented in the `BeerShortwave` type.

Here's an example usage:

```@example usepkg
using PlantBiophysics, PlantSimEngine

m = ModelList(BeerShortwave(0.6), status=(LAI=2.0,))

meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)

run!(m, meteo)

m
```

!!! note
    If you have a 3D plant in the OPF format, you can use [Archimed-ϕ](https://archimed-platform.github.io/archimed-phys-user-doc/).
