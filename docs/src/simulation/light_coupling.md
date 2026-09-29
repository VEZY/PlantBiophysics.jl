# Coupling light and leaf physiology

Use this guide when radiation comes from a canopy light model or a 3D light
simulation. For choosing a Beer-Lambert model and running it on its own,
start with [Light interception](../models/light.md).

The first question is the area used to express radiation. A canopy output is
per unit **ground area**, whereas a leaf model needs radiation per unit
**leaf area**. The conversion models below use leaf area index (`LAI`) to
calculate a canopy mean per leaf area. Light resolved on a leaf mesh already
uses that mesh's surface area and follows a different route.

## Convert canopy radiation before leaf physiology

This complete example uses one `BeerShortwave` model to calculate both PAR
and shortwave absorption for a canopy. Two conversion models divide its
outputs by `LAI`; a representative leaf then uses these mean values to
calculate photosynthesis and energy balance. This does not distinguish
sunlit and shaded leaves.

First, describe the weather and a plant containing one representative leaf.
The plant supplies `LAI`, while the leaf supplies its sky view and characteristic
dimension:

```@example light_coupling
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

weather = Atmosphere(
    T=20.0, Wind=1.0, P=101.3, Rh=0.65,
    Ri_PAR_f=300.0, Ri_NIR_f=350.0, duration=Hour(1),
)
objects = (
    Object(:plant; scale=:Plant, status=Status(LAI=2.0)),
    Object(
        :leaf; scale=:Leaf, parent=:plant,
        status=Status(sky_fraction=1.0, d=0.03),
    ),
)
nothing # hide
```

The canopy applications calculate the ground-area fluxes and convert them
to mean leaf-area fluxes. `Self()` finds the current plant; naming the source
application makes each connection explicit. `HoldLast()` uses the latest
available value until its source updates it.

```@example light_coupling
canopy_models = (
    ModelSpec(
        BeerShortwave(0.6); name=:canopy_light, on=One(scale=:Plant),
    ),
    ModelSpec(
        GroundToMeanLeafPPFD();
        name=:mean_leaf_ppfd, on=One(scale=:Plant),
        inputs=(
            :aPPFD_ground => One(
                within=Self(), application=:canopy_light,
                var=:aPPFD, policy=HoldLast(),
            ),
        ),
    ),
    ModelSpec(
        GroundToMeanLeafShortwave();
        name=:mean_leaf_shortwave, on=One(scale=:Plant),
        inputs=(
            :Ra_SW_f_ground => One(
                within=Self(), application=:canopy_light,
                var=:Ra_SW_f, policy=HoldLast(),
            ),
        ),
    ),
)
nothing # hide
```

Next, connect the leaf models to the converted radiation. `SelfPlant()`
finds the plant containing the leaf. `Fvcb` receives the converted photon
flux, and `Monteith` receives the converted shortwave radiation:

```@example light_coupling
leaf_models = (
    ModelSpec(
        Fvcb(); name=:photosynthesis, on=One(scale=:Leaf),
        inputs=(
            :aPPFD => One(
                scale=:Plant, within=SelfPlant(),
                application=:mean_leaf_ppfd,
                var=:aPPFD_leaf_mean, policy=HoldLast(),
            ),
        ),
    ),
    ModelSpec(
        Monteith(); name=:energy_balance, on=One(scale=:Leaf),
        inputs=(
            :Ra_SW_f => One(
                scale=:Plant, within=SelfPlant(),
                application=:mean_leaf_shortwave,
                var=:Ra_SW_f_leaf_mean, policy=HoldLast(),
            ),
        ),
    ),
    ModelSpec(
        Medlyn(0.03, 12.0);
        name=:stomatal_conductance, on=One(scale=:Leaf),
    ),
)
nothing # hide
```

Combine these applications in one scene and run it. The `...` syntax expands
both tuples into the full list of models or objects:

```@example light_coupling
coupled_scene = CompositeModel(
    objects...;
    applications=(canopy_models..., leaf_models...),
    environment=weather,
)
run!(coupled_scene)
leaf = model_object(coupled_scene, :leaf)
(
    Rn=leaf.status.Rn, H=leaf.status.H, λE=leaf.status.λE,
    Tₗ=leaf.status.Tₗ, A=leaf.status.A, Gₛ=leaf.status.Gₛ,
)
```

The heat fluxes are in W m⁻² leaf, temperature is in °C, assimilation is in
µmol CO₂ m⁻² leaf s⁻¹, and stomatal conductance is in mol CO₂ m⁻² leaf s⁻¹.
You can inspect the conversion separately:

```@example light_coupling
plant = model_object(coupled_scene, :plant)
(
    ground_PPFD=plant.status.aPPFD,
    mean_leaf_PPFD=plant.status.aPPFD_leaf_mean,
    ground_shortwave=plant.status.Ra_SW_f,
    mean_leaf_shortwave=plant.status.Ra_SW_f_leaf_mean,
)
```

With `LAI=2`, the mean leaf-area values are half the ground-area values.
The photon flux is in µmol photons m⁻² s⁻¹ and shortwave radiation is in
W m⁻², with the area basis given by each name.

Both conversion models reject non-finite or non-positive `LAI`, as well as negative or
non-finite radiation. PlantSimEngine also rejects a direct Beer-to-FvCB or
BeerShortwave-to-Monteith connection because the producer is ground-based and
no conversion boundary was declared.

These two conversion models are specific to the ground-area canopy rates produced by `Beer` and
`BeerShortwave`. Do not use them for geometry-resolved light: dividing an
organ-level irradiance by canopy LAI would apply the wrong area conversion.

## Couple 3D light directly to physiology

Use **ArchimedLight.jl 0.2.0 or later** for this coupling. Its
`ArchimedLightModel` publishes the light and sky-view results from a 3D scene
to each selected leaf object. The default `:coupling` output schema includes
`aPPFD` (µmol photons m⁻² s⁻¹), `Ra_SW_f` (W m⁻²), `area` (m²), and
`sky_fraction` (dimensionless). The two radiation fluxes use the mesh surface
as their area basis, so FvCB and Monteith can use them directly. `sky_fraction` is used by `Monteith` to calculate the longwave radiation exchange, with the assumption that most of the exchanges of thermal radiation are between the organ and the sky, because other objects have a temperature that is within a few degrees of the organ's temperature, whereas the sky usually has a much lower temperature.

Given a scene application named `:archimed_light` whose `outputs_to` selector
covers the leaves, bind the published values to the physiology applications:

```julia
leaf = Object(:leaf_42; scale=:Leaf, status=Status(d=0.03))

photosynthesis = ModelSpec(
    Fvcb(); name=:photosynthesis, on=Many(scale=:Leaf),
    inputs=(
        :aPPFD => One(
            within=Self(), application=:archimed_light, var=:aPPFD,
            policy=HoldLast(),
        ),
    ),
)

energy_balance = ModelSpec(
    Monteith(); name=:energy_balance, on=Many(scale=:Leaf),
    inputs=(
        :Ra_SW_f => One(
            within=Self(), application=:archimed_light, var=:Ra_SW_f,
            policy=HoldLast(),
        ),
        :sky_fraction => One(
            within=Self(), application=:archimed_light, var=:sky_fraction,
            policy=HoldLast(),
        ),
    ),
)
```

Include these applications with the ArchimedLight scene application in the
`CompositeModel`. PlantSimEngine schedules the scene calculation before its
leaf consumers. The leaf's `d` remains a physiology input; its `sky_fraction`
comes from the scene calculation. See the
[ArchimedLight PlantSimEngine coupling guide](https://vezy.github.io/ArchimedLight.jl/stable/plantsimengine/)
for the scene application and its organ selector.

Use `Diagnostics.explain_bindings`, `Diagnostics.explain_writers`, and
`Diagnostics.explain_schedule` to verify the sources and execution order.

## Record radiation totals

This example uses the standalone canopy `scene` from the
[Light interception example](../models/light.md), independently of
`coupled_scene` above. It repeats the same conditions for 24 hourly steps
to illustrate conversion from rates to totals.

`outputs=:all` records these raw rates at each step. Request an integrated
quantity only at the boundary that needs it, for example:

```julia
requests = [
    OutputRequest(
        Many(scale=:Plant),
        :aPPFD;
        name=:absorbed_photons,
        application=:canopy_light,
        policy=Integrate(PlantMeteo.DurationSumReducer()),
        clock=Hour(24),
    ),
    OutputRequest(
        Many(scale=:Plant),
        :Ra_SW_f;
        name=:absorbed_shortwave_energy,
        application=:canopy_light,
        policy=Integrate(PlantMeteo.RadiationEnergy()),
        clock=Hour(24),
    ),
]
simulation = run!(scene; steps=24, outputs=requests)
```

`DurationSumReducer` converts a photon rate to the corresponding duration sum;
`RadiationEnergy` converts irradiance to `MJ m[ground]⁻²` over the requested
window. Neither changes the current rate stored on the Plant status.

