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

Use **[ArchimedLight.jl](https://vezy.github.io/ArchimedLight.jl/stable/) 0.2.0 or later** for this example, together with `PlantGeom`, `GeometryBasics`,
`MultiScaleTreeGraph`, and `DataFrames`. The code below is self-contained:
it creates two rectangular leaves, places one above the other, and calculates
light interception, leaf temperature, photosynthesis, and stomatal conductance.
No plant file is needed. Run the blocks in order.

First, build the geometry in metres and choose the leaves' optical properties.
Each rectangle is 10 cm long and 3 cm wide. The optical coefficients below
scatter 15% of incident PAR and 30% of incident near-infrared radiation;
the remaining radiation is absorbed. These are illustrative values. The scene
domain includes empty space around the leaves so oblique sky rays reach them.

```julia
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates, DataFrames
using ArchimedLight, PlantGeom, GeometryBasics, MultiScaleTreeGraph

lamina = GeometryBasics.Mesh(
    Point3f[
        Point3f(0, 0, 0), Point3f(0.10, 0, 0),
        Point3f(0.10, 0.03, 0), Point3f(0, 0.03, 0),
    ],
    TriangleFace{Int}[
        TriangleFace{Int}(1, 2, 3), TriangleFace{Int}(1, 3, 4),
    ],
)
geometry = PlantGeom.make_scene(domain=(-2.0, -2.0, 2.0, 2.0)) do builder
    PlantGeom.add_object!(builder, lamina;
        group="plant", type="Leaf", id=1, at=(0.0, 0.0, 0.10))
    PlantGeom.add_object!(builder, lamina;
        group="plant", type="Leaf", id=2, at=(0.0, 0.0, 0.20))
end
optical_models = ArchimedLight.models_for(
    "plant" => ("Leaf" => ArchimedLight.translucent(par=0.15, nir=0.30),),
)
light_sim = LightSimulation(
    geometry, optical_models;
    options=LightOptions(
        turtle_sectors=16, pixel_size=0.002,
        scattering=false, toricity=false,
    ),
)
```

Next, declare the four model applications. ArchimedLight runs once on the
scene and publishes its results to both leaves. FvCB reads the absorbed
photon flux (`aPPFD`, µmol photons m⁻² s⁻¹); Monteith reads absorbed shortwave
radiation (`Ra_SW_f`, W m⁻²) and the visible-sky fraction (`sky_fraction`).
These fluxes are already expressed per unit leaf mesh area, so no LAI
conversion is needed. Monteith uses the sky fraction for longwave exchange
and couples leaf temperature with FvCB and Medlyn on the same leaf.

```julia
light_application = ModelSpec(
    ArchimedLightModel(light_sim;
        par_energy_to_photon=Constants().J_to_umol);
    name=:archimed_light, on=One(scale=:Scene),
    outputs_to=(
        OutputTo(Many(scale=:Leaf, within=SceneScope()); coverage=:exact),
    ),
)
photosynthesis = ModelSpec(
    Fvcb(); name=:photosynthesis, on=Many(scale=:Leaf),
    inputs=(
        :aPPFD => One(
            within=Self(), application=:archimed_light, var=:aPPFD,
            policy=HoldLast(),
        ),
    ),
)
stomatal_conductance = ModelSpec(
    Medlyn(0.03, 12.0); name=:stomatal_conductance, on=Many(scale=:Leaf),
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

Finally, supply the weather and assemble the `CompositeModel` from the same
MTG as the geometry. This keeps each leaf's light results associated with
the correct simulation object. The only leaf input we initialize is its
characteristic dimension `d` (m); ArchimedLight supplies radiation, area,
and sky fraction. Here the sun is overhead and 80% of incident radiation
is direct. `HoldLast()` uses the latest light result; PlantSimEngine
schedules ArchimedLight before the leaf calculations.

```julia
weather_3d = Atmosphere(
    T=25.0, Wind=1.0, P=101.3, Rh=0.65, Cₐ=400.0,
    Ri_PAR_f=300.0, Ri_NIR_f=350.0, duration=Hour(1),
    sun_azimuth_deg=180.0, sun_elevation_deg=90.0, direct_fraction=0.8,
)
initial_leaf_status(node) = MultiScaleTreeGraph.symbol(node) == :Leaf ?
    Status(d=0.03) : Status()

coupled_3d = CompositeModel(
    geometry.mtg;
    status=initial_leaf_status,
    applications=(light_application, energy_balance,
        photosynthesis, stomatal_conductance),
    environment=weather_3d,
)
simulation_3d = run!(coupled_3d; outputs=:all)

leaf_ids = object_ids(coupled_3d; scale=:Leaf)
leaf_states = [final_state(simulation_3d, id) for id in leaf_ids]
DataFrame(
    leaf=leaf_ids,
    aPPFD=getproperty.(leaf_states, :aPPFD),
    sky_fraction=getproperty.(leaf_states, :sky_fraction),
    Rn=getproperty.(leaf_states, :Rn),
    H=getproperty.(leaf_states, :H),
    λE=getproperty.(leaf_states, :λE),
    Tₗ=getproperty.(leaf_states, :Tₗ),
    A=getproperty.(leaf_states, :A),
    Gₛ=getproperty.(leaf_states, :Gₛ),
)
```

The table contains one row per leaf. Compare their absorbed light and sky
view, then their net radiation (`Rn`), sensible heat (`H`), latent heat
(`λE`, all W m⁻²), temperature (`Tₗ`, °C), photosynthesis
(`A`, µmol CO₂ m⁻² s⁻¹), and stomatal conductance
(`Gₛ`, mol CO₂ m⁻² s⁻¹). The lower leaf is shaded by the upper one.
With these settings, the results are approximately:

| Leaf | `aPPFD` | `Rn` | `H` | `λE` | `Tₗ` | `A` | `Gₛ` |
|:--|--:|--:|--:|--:|--:|--:|--:|
| Lower, shaded | 150 | 68.8 | -68.1 | 136.9 | 23.65 | 10.0 | 0.392 |
| Upper, exposed | 1165 | 493.0 | 99.8 | 393.1 | 26.96 | 34.9 | 1.115 |

For larger scenes and alternative output schemas, see the
[ArchimedLight PlantSimEngine coupling guide](https://vezy.github.io/ArchimedLight.jl/stable/plantsimengine/).
Use `Diagnostics.explain_bindings(coupled_3d)` and
`Diagnostics.explain_schedule(coupled_3d)` to inspect the connections and
execution order.

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

