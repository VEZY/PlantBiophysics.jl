# [Light Interception](@id light_page)

PlantBiophysics provides two Beer-Lambert implementations:

- [`Beer`](@ref) computes absorbed photosynthetic photon flux density
  (`aPPFD`);
- [`BeerShortwave`](@ref) also computes absorbed shortwave radiation
  (`Ra_SW_f`) for energy-balance models.

These are canopy models. Their radiation outputs are expressed per unit ground
area, not per unit leaf area. `LAI` is the ratio of leaf area to ground area.
The outputs remain current per-second rates on status; request temporal
integration explicitly when exporting totals.

```@example light
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

scene = CompositeModel(
    Object(:plant; scale=:Plant, status=Status(LAI=2.0));
    applications=(
        ModelSpec(
            BeerShortwave(0.6);
            name=:canopy_light,
            on=One(scale=:Plant),
        ),
    ),
    environment=Atmosphere(
        T=20.0,
        Wind=1.0,
        P=101.3,
        Rh=0.65,
        Ri_PAR_f=300.0,
        Ri_NIR_f=350.0,
        duration=Hour(1),
    ),
)

run!(scene)
plant = model_object(scene, :plant)
(aPPFD=plant.status.aPPFD, Ra_SW_f=plant.status.Ra_SW_f)
```

The values above are therefore in `μmol[photon] m[ground]⁻² s⁻¹` and
`W m[ground]⁻²`, respectively. The one-argument `BeerShortwave(k)` constructor
preserves the historical NIR coefficient `k_NIR = 0.48`. Pass both coefficients
as `BeerShortwave(k_PAR, k_NIR)` to choose another value.

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

## Convert canopy radiation before leaf physiology

Leaf photosynthesis and energy balance consume radiation per unit leaf area.
Put an explicit conversion model between a Beer canopy output and either leaf
model. The source-to-adapter and adapter-to-consumer mappings are both named;
`HoldLast()` makes their temporal meaning explicit.

For absorbed PPFD, map `Beer.aPPFD` to `aPPFD_ground`, then map the distinct
leaf-mean output to the photosynthesis input:

```julia
ModelSpec(
    Beer(0.6);
    name=:canopy_light,
    on=Many(scale=:Plant),
)

ModelSpec(
    GroundToMeanLeafPPFD();
    name=:mean_leaf_ppfd,
    on=Many(scale=:Plant),
    inputs=(
        :aPPFD_ground => One(
            within=Self(),
            application=:canopy_light,
            var=:aPPFD,
            policy=HoldLast(),
        ),
    ),
)

ModelSpec(
    Fvcb();
    name=:photosynthesis,
    on=Many(scale=:Leaf),
    inputs=(
        :aPPFD => One(
            scale=:Plant,
            within=SelfPlant(),
            application=:mean_leaf_ppfd,
            var=:aPPFD_leaf_mean,
            policy=HoldLast(),
        ),
    ),
)
```

For energy balance, use the analogous shortwave boundary:

```julia
ModelSpec(
    BeerShortwave(0.6);
    name=:canopy_light,
    on=Many(scale=:Plant),
)

ModelSpec(
    GroundToMeanLeafShortwave();
    name=:mean_leaf_shortwave,
    on=Many(scale=:Plant),
    inputs=(
        :Ra_SW_f_ground => One(
            within=Self(),
            application=:canopy_light,
            var=:Ra_SW_f,
            policy=HoldLast(),
        ),
    ),
)

ModelSpec(
    Monteith();
    name=:energy_balance,
    on=Many(scale=:Leaf),
    inputs=(
        :Ra_SW_f => One(
            scale=:Plant,
            within=SelfPlant(),
            application=:mean_leaf_shortwave,
            var=:Ra_SW_f_leaf_mean,
            policy=HoldLast(),
        ),
    ),
)
```

Both adapters reject non-finite or non-positive `LAI`, as well as negative or
non-finite radiation. PlantSimEngine also rejects a direct Beer-to-FvCB or
BeerShortwave-to-Monteith connection because the producer is ground-based and
no conversion boundary was declared.

These two adapters are specific to the ground-area canopy rates produced by `Beer` and
`BeerShortwave`. Do not use them for geometry-resolved light: dividing an
organ-level irradiance by canopy LAI would apply the wrong area conversion.

!!! compat "Historical ARCHIMED model files"
    PlantBiophysics does not parse ARCHIMED light-model YAML or provide a
    per-organ `Translucent` copier. Use `ArchimedLight.read_models` for those
    optical definitions. To ignore light interception, omit the light
    application; a no-op model is unnecessary.

## Convert 3D light on its own area boundary

ArchimedLight organ flux densities are normalized by `radiative_mesh_area`.
That area can differ from the botanical leaf area used by FvCB and Monteith.
The raw `aPPFD` and `Ra_SW_f` values must therefore not be connected directly
to those physiology inputs.

Use a separate explicit conversion for each organ:

```math
\mathrm{flux}_{leaf} =
\mathrm{flux}_{radiative}\,
\frac{\mathrm{radiative\_mesh\_area}}{\mathrm{botanical\_leaf\_area}}.
```

This preserves the absorbed amount while changing the normalization area. A
leaf must therefore carry an explicit, finite, positive
`botanical_leaf_area`. Put [`RadiativeMeshToLeafPPFD`](@ref) and
[`RadiativeMeshToLeafShortwave`](@ref) between the ArchimedLight scene writer
and the physiology models:

```julia
leaf = Object(
    :leaf_42;
    scale=:Leaf,
    status=Status(
        botanical_leaf_area=0.012,
        sky_fraction=1.0,
        d=0.03,
    ),
)

ppfd_boundary = ModelSpec(
    RadiativeMeshToLeafPPFD();
    name=:radiative_to_leaf_ppfd,
    on=Many(scale=:Leaf),
    inputs=(
        :aPPFD_radiative => One(
            within=Self(), application=:archimed_light, var=:aPPFD,
            policy=HoldLast(),
        ),
        :radiative_mesh_area => One(
            within=Self(), application=:archimed_light,
            var=:radiative_mesh_area, policy=HoldLast(),
        ),
    ),
)

shortwave_boundary = ModelSpec(
    RadiativeMeshToLeafShortwave();
    name=:radiative_to_leaf_shortwave,
    on=Many(scale=:Leaf),
    inputs=(
        :Ra_SW_f_radiative => One(
            within=Self(), application=:archimed_light, var=:Ra_SW_f,
            policy=HoldLast(),
        ),
        :radiative_mesh_area => One(
            within=Self(), application=:archimed_light,
            var=:radiative_mesh_area, policy=HoldLast(),
        ),
    ),
)
```

Map `aPPFD_leaf_mean` from `ppfd_boundary` to FvCB's `aPPFD` input, and
`Ra_SW_f_leaf_mean` from `shortwave_boundary` to Monteith's `Ra_SW_f` input.
The distinct names prevent raw radiative-area values from being mistaken for
leaf-area values, and PlantSimEngine rejects a contracted direct connection.
The Beer LAI adapters above are not a substitute for this organ-area boundary.

Keep source ownership exact. Build the `CompositeModel` from the same MTG as
the `PlantGeom.SceneGeometry` when possible. For another topology, pass exact
MTG roots through `source_roots`, or an explicit `object_resolver` from each
source-owner key to its `ObjectId`. Never infer this relationship from row or
traversal order.

ArchimedLight raw `aPPFD` is in
``\mu mol\ m_{\mathrm{radiative}}^{-2}\ s^{-1}`` and raw `Ra_SW_f` is in
``W\ m_{\mathrm{radiative}}^{-2}``.
After the conversion bindings are compiled, `final_state(...).aPPFD` and
`final_state(...).Ra_SW_f` are the botanical-leaf-area values seen by FvCB and
Monteith. Read the raw radiative-area values from the `:archimed_light` output
history when both representations are needed.
The same sampled environment row must provide sun azimuth in [0, 360°), sun
elevation in [-90°, 90°], non-negative incident PAR and NIR (``W\ m^{-2}``), a
direct fraction in [0, 1], and a finite, strictly positive timestep duration.

`sky_fraction` is deliberately absent from both `ArchimedLightModel` output
schemas (`:coupling` and `:full`). It is the longwave sky-view assumption used
by [`Monteith`](@ref), including the chosen one- or two-sided convention, and
must be initialized explicitly as scenario state for every leaf. Its valid
range is 0–2: 0 means that neither effective leaf face sees the sky, 1
corresponds to one fully exposed effective face, and 2 to both faces seeing
the sky. This keeps a shortwave interception result from silently standing in
for a scientifically distinct longwave view factor.

Use
`Diagnostics.explain_bindings`, `Diagnostics.explain_writers`, and
`Diagnostics.explain_schedule` to verify both conversion edges and their
ordering before the Monteith → FvCB → stomatal-conductance hard-call chain.
