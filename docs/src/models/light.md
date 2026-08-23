# [Light Interception](@id light_page)

PlantBiophysics provides two Beer-Lambert implementations:

- [`Beer`](@ref) computes absorbed photosynthetic photon flux density
  (`aPPFD`);
- [`BeerShortwave`](@ref) also computes absorbed shortwave radiation
  (`Ra_SW_f`) for energy-balance models.

```@example light
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

scene = leaf_scene(
    BeerShortwave(0.6);
    status=Status(LAI=2.0),
    environment=Atmosphere(
        T=20.0,
        Wind=1.0,
        P=101.3,
        Rh=0.65,
        Ri_PAR_f=300.0,
        Ri_SW_f=650.0,
        duration=Hour(1),
    ),
)

run!(scene)
leaf = only(model_objects(scene; scale=:Leaf))
(aPPFD=leaf.status.aPPFD, Ra_SW_f=leaf.status.Ra_SW_f)
```

## Couple one 3D light simulation to many leaves

For geometrically explicit plants, use one scene-scale ArchimedLight writer and
ordinary PlantBiophysics models on `Leaf`. PlantSimEngine derives the
light-to-physiology schedule from the variables written by ArchimedLight; no
per-leaf copying model, positional table join, `from_status`, or manual `after`
constraint is needed.

The following is the composition pattern. `light_simulation` is an
`ArchimedLight.LightSimulation` prepared from a `PlantGeom.SceneGeometry`. When
possible, build the `CompositeModel` from that exact `scene.mtg` so source
owners resolve natively. For another object topology, pass exact MTG roots
through `source_roots`, or an explicit `object_resolver` from each source-owner
key to its `ObjectId`. Never infer this relationship from row or traversal
order.

```julia
using ArchimedLight, PlantBiophysics, PlantSimEngine

light = ArchimedLightModel(light_simulation)

applications = (
    ModelSpec(Monteith(); name=:energy_balance, on=Many(scale=:Leaf)),
    ModelSpec(Fvcb(); name=:photosynthesis, on=Many(scale=:Leaf)),
    ModelSpec(
        Medlyn(0.03, 12.0);
        name=:stomatal_conductance,
        on=Many(scale=:Leaf),
    ),
    ModelSpec(
        light;
        name=:archimed_light,
        on=One(scale=:Scene),
        outputs_to=(
            organs=OutputTo(
                Many(scale=:Leaf, within=SceneScope());
                vars=archimed_light_outputs(:coupling),
            ),
        ),
    ),
)

scene = CompositeModel(
    scene_objects...;
    applications=applications,
    environment=forcing,
)
```

The coupling schema publishes `aPPFD` for FvCB photosynthesis and `Ra_SW_f`
for the Monteith energy balance, together with PAR/NIR diagnostics and the
radiative mesh area. Flux densities are per unit radiative mesh area;
`aPPFD` is in ``\mu mol\ m^{-2}\ s^{-1}`` and `Ra_SW_f` in ``W\ m^{-2}``.
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

Use `Diagnostics.explain_bindings`, `Diagnostics.explain_writers`, and
`Diagnostics.explain_schedule` to confirm that `:archimed_light` owns the leaf
light variables and runs before `:energy_balance`. The Monteith → FvCB →
stomatal-conductance chain remains a normal PlantSimEngine hard-call chain.
