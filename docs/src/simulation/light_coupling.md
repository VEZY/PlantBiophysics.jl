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

!!! compat "Historical ARCHIMED model files"
    PlantBiophysics does not parse ARCHIMED light-model YAML or provide a
    per-organ `Translucent` copier. Use `ArchimedLight.read_models` for those
    optical definitions. To ignore light interception, omit the light
    application; a no-op model is unnecessary.

## Couple 3D light directly to physiology

ArchimedLight and PlantBiophysics use the represented mesh surface as the
reference area for geometry-resolved radiation. ArchimedLight publishes
`aPPFD` in `μmol[photon] m⁻² s⁻¹`, `Ra_SW_f` in `W m⁻²`, and the corresponding
mesh surface `area` in `m²` for each destination organ. FvCB and Monteith use
the same `:surface_area` radiation contracts, so those fluxes couple directly.
The light solver's pixel projection correction does not change the reference
surface area.

For a leaf mesh, this represented surface is the leaf area used by the
physiology calculation. Leaf-area model parameters and observations must use
that same reference surface. Beer-Lambert canopy fluxes still require the
LAI adapters above because their denominator is ground area.

Given an ArchimedLight scene application named `:archimed_light` that publishes
to the leaf objects, bind its radiation directly to the physiology models:

```julia
leaf = Object(
    :leaf_42;
    scale=:Leaf,
    status=Status(sky_fraction=1.0, d=0.03),
)

photosynthesis = ModelSpec(
    Fvcb();
    name=:photosynthesis,
    on=Many(scale=:Leaf),
    inputs=(
        :aPPFD => One(
            within=Self(), application=:archimed_light, var=:aPPFD,
            policy=HoldLast(),
        ),
    ),
)

energy_balance = ModelSpec(
    Monteith();
    name=:energy_balance,
    on=Many(scale=:Leaf),
    inputs=(
        :Ra_SW_f => One(
            within=Self(), application=:archimed_light, var=:Ra_SW_f,
            policy=HoldLast(),
        ),
    ),
)

stomatal_conductance = ModelSpec(
    Medlyn(0.03, 12.0);
    name=:stomatal_conductance,
    on=Many(scale=:Leaf),
)
```

Include these applications alongside the scene light application in the
`CompositeModel`. PlantSimEngine runs the light calculation before the coupled leaf
energy-balance, photosynthesis, and stomatal-conductance models. The flux values read
by FvCB and Monteith are the values published by ArchimedLight.

Match each mesh to the correct plant object. Build the `CompositeModel` from the same MTG as
the `PlantGeom.SceneGeometry` when possible. For another topology, pass exact
MTG roots through `source_roots`, or an explicit `object_resolver` from each
source-owner key to its `ObjectId`. Never infer this relationship from row or
traversal order.

The same sampled environment row must provide sun azimuth in [0, 360°), sun
elevation in [-90°, 90°], non-negative incident PAR and NIR (`W m⁻²`), a
direct fraction in [0, 1], and a finite, strictly positive timestep duration.

`sky_fraction` is deliberately absent from both `ArchimedLightModel` output
schemas (`:coupling` and `:full`). It is the longwave sky-view assumption used
by [`Monteith`](@ref), including the chosen one- or two-sided convention, and
must be initialized explicitly as scenario state for every leaf. Its valid
range is 0–2: 0 means that neither effective leaf face sees the sky, 1
corresponds to one fully exposed effective face, and 2 to both faces seeing
the sky. This keeps a shortwave interception result from silently standing in
for a scientifically distinct longwave view factor.

Use `Diagnostics.explain_bindings`, `Diagnostics.explain_writers`, and
`Diagnostics.explain_schedule` to verify the radiation sources and execution
order.

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

