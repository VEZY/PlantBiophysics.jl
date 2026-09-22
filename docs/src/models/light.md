# [Light interception](@id light_page)

Light-interception models estimate how much incoming radiation a canopy
absorbs. Photosynthesis uses the photosynthetically active part of the
spectrum (**PAR**); leaf energy balance also needs near-infrared radiation
(**NIR**).

## Choose a model

Both models use the Beer-Lambert law: the absorbed fraction increases with
leaf area index (`LAI`, leaf area divided by ground area) and an extinction
coefficient `k`. For one spectral band, that fraction is `1 - exp(-k * LAI)`.

| Model | Weather inputs | Main outputs | Use when |
|:--|:--|:--|:--|
| [`Beer(k)`](@ref Beer) | Incident PAR, `Ri_PAR_f` | Absorbed photon flux, `aPPFD` | You need light for photosynthesis |
| [`BeerShortwave(k_PAR, k_NIR)`](@ref BeerShortwave) | Incident PAR and NIR, `Ri_PAR_f` and `Ri_NIR_f` | `aPPFD` and absorbed shortwave radiation, `Ra_SW_f` | You also need radiation for energy balance |

The coefficients describe light extinction in the canopy. The shorter form
`BeerShortwave(k_PAR)` uses `k_NIR = 0.48`. That number is an extinction
coefficient, not a PAR-to-shortwave conversion factor.

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
    Object(:plant; scale=:Plant, status=Status(LAI=2.0));
    applications=(
        ModelSpec(
            BeerShortwave(0.6);
            name=:canopy_light,
            on=One(scale=:Plant),
        ),
    ),
    environment=meteo,
)

run!(scene)
plant = model_object(scene, :plant)
(aPPFD=plant.status.aPPFD, Ra_SW_f=plant.status.Ra_SW_f)
```

`Object` represents the canopy, and `ModelSpec` assigns the light model to
it. The example uses the plant scale because the Beer-Lambert calculation
describes a canopy rather than an individual leaf.

The output `aPPFD` is in µmol photons m⁻² ground s⁻¹, and `Ra_SW_f` is in
W m⁻² ground. `BeerShortwave` also provides the absorbed PAR and NIR
separately as `Ra_PAR_f` and `Ra_NIR_f`:

```@example light
(Ra_PAR_f=plant.status.Ra_PAR_f, Ra_NIR_f=plant.status.Ra_NIR_f)
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
