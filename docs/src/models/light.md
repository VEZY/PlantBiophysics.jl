# [Light interception](@id light_page)

Light-interception models estimate how much incoming radiation a leaf or canopy
absorbs. Photosynthesis uses the photosynthetically active part of the
spectrum (**PAR**); leaf energy balance also needs near-infrared radiation
(**NIR**).

## Choose a model

For a leaf with known incoming light, use `ConstantAbsorption` to absorb a
fixed fraction. For a canopy, use a Beer-Lambert model to calculate absorption
from leaf area index (`LAI`, leaf area divided by ground area).

| Model | Weather inputs | Main outputs | Use when |
|:--|:--|:--|:--|
| [`ConstantAbsorption(α_PAR, α_NIR)`](@ref ConstantAbsorption) | Incident PAR and NIR at the surface | `aPPFD` and `Ra_SW_f`, per surface area | You want fixed absorption fractions, for example under controlled leaf lighting |
| [`Beer(k)`](@ref Beer) | Incident PAR, `Ri_PAR_f` | Absorbed photon flux, `aPPFD` | You need light for photosynthesis |
| [`BeerShortwave(k_PAR, k_NIR)`](@ref BeerShortwave) | Incident PAR and NIR, `Ri_PAR_f` and `Ri_NIR_f` | `aPPFD` and absorbed shortwave radiation, `Ra_SW_f` | You also need radiation for energy balance |

The Beer-Lambert coefficients describe light extinction in the canopy. For
each band, the absorbed fraction is `1 - exp(-k * LAI)`. The shorter form
`BeerShortwave(k_PAR)` uses `k_NIR = 0.48`. That number is an extinction
coefficient, not a PAR-to-shortwave conversion factor.

Another model is [`ArchimedLight`](https://vezy.github.io/ArchimedLight.jl/stable/), which calculates 3D light interception in a 3D canopy. This model is in a separate package external to PlantBiophysics, but is still fully compatible with PlantBiophysics's models. 

## Absorb a fixed fraction at the leaf

`ConstantAbsorption(α_PAR=0.8, α_NIR=0.2)` absorbs 80% of incident PAR and
20% of incident NIR. These illustrative fractions are supplied explicitly;
they must lie between 0 and 1. The equations are:

```math
R_{a,PAR} = \alpha_{PAR} R_{i,PAR}, \qquad
R_{a,NIR} = \alpha_{NIR} R_{i,NIR}, \qquad
R_{a,SW} = R_{a,PAR} + R_{a,NIR}.
```

Absorbed photon flux `aPPFD` is `Ra_PAR_f * constants.J_to_umol`.
All radiation uses the same represented surface area, so the model couples
directly to leaf photosynthesis and energy balance. Add it to the simple
`CompositeModel` constructor, as in the
[several-timestep tutorial](../simulation/several_simulation.md).

For controlled lighting, incident light is often specified as photon flux.
Here we simulate a leaf under 1000 µmol photons m⁻² s⁻¹, assuming no incident
NIR and an absorbed PAR fraction of 0.8:

```@example constant_absorption
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

constants = Constants()
incident_ppfd = 1000.0
weather = Atmosphere(
    T=25.0, Wind=1.0, P=101.3, Rh=0.6, duration=Minute(1),
    Ri_PAR_f=incident_ppfd / constants.J_to_umol,
    Ri_NIR_f=0.0,
)
scene = CompositeModel(
    ConstantAbsorption(α_PAR=0.8, α_NIR=0.2);
    environment=weather,
)
run!(scene; constants=constants)
leaf = only(model_objects(scene))
(aPPFD=leaf.status.aPPFD, Ra_SW_f=leaf.status.Ra_SW_f)
```

The absorbed photon flux is 800 µmol photons m⁻² s⁻¹. To reproduce a specific
chamber experiment, choose the absorption fractions and `J_to_umol` for the
leaf and lamp spectrum; see [LI-COR's light settings](https://www.licor.com/env/support/LI-6800/topics/environment-light-control.html).
Imported `aPPFD` values from the LI-COR readers are already absorbed photon
fluxes: use them directly rather than applying absorption a second time.

The model has no imposed timestep or object scale. At any timestep duration,
it returns fluxes for the current incoming light, without multiplying by
duration. At other spatial scales, incoming and absorbed radiation must still
refer to the same surface area. It does not calculate shading or convert
ground-area radiation to leaf-area radiation.

## Run a canopy light simulation

Here we use `LAI = 2.0`, `k_PAR = 0.6`, and the default NIR coefficient.
The incoming PAR and NIR are in W m⁻² of ground area.

```@example light
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

meteo = Atmosphere(
    T=20.0, Wind=1.0, P=101.3, Rh=0.65,
    Ri_PAR_f=300.0, Ri_NIR_f=350.0, duration=Hour(1),
)

scene = CompositeModel(
    BeerShortwave(0.6);
    status=Status(LAI=2.0),
    environment=meteo,
)

run!(scene)
canopy = only(model_objects(scene))
(aPPFD=canopy.status.aPPFD, Ra_SW_f=canopy.status.Ra_SW_f)
```

`CompositeModel` applies the light model to one object, representing the
canopy. Its status supplies the leaf area index and stores the calculated
radiation.

The output `aPPFD` is in µmol photons m⁻² ground s⁻¹, and `Ra_SW_f` is in
W m⁻² ground. `BeerShortwave` also provides the absorbed PAR and NIR
separately as `Ra_PAR_f` and `Ra_NIR_f`:

```@example light
(Ra_PAR_f=canopy.status.Ra_PAR_f, Ra_NIR_f=canopy.status.Ra_NIR_f)
```

These are rates at the simulated conditions. Use `outputs=:all` when running
several timesteps to keep a history, as in the
[several-timestep tutorial](../simulation/several_simulation.md).

## Use the light in a leaf simulation

A canopy output is per unit **ground area**, while leaf photosynthesis and
energy balance need radiation per unit **leaf area**. To obtain the canopy
mean per leaf area, use `GroundToMeanLeafPPFD` for photons and
`GroundToMeanLeafShortwave` for shortwave radiation. These conversion models
use the canopy's `LAI`; they do not describe differences between sunlit and
shaded leaves.

[Coupling light and leaf physiology](../simulation/light_coupling.md) shows
how to connect these models, how to use 3D radiation from ArchimedLight,
and how to record daily radiation totals. If you already have measured or
prescribed radiation per leaf area, you can provide it directly, as in the
[TL;DR leaf example](../getting_started/get_started.md).
