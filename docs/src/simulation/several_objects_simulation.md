# Simulation Over Several Objects

This tutorial runs the same coupled PlantBiophysics model on two leaves. The
leaves share one weather sequence, while each keeps its own state and absorbed
radiation.

## Build a small plant

`Object` describes the entities in the simulation. Here a scene contains one
plant with a sunlit and a shaded leaf:

```@example several_objects
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates, DataFrames

weather = Weather([
    Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, duration=Hour(1)),
    Atmosphere(T=23.0, Wind=1.5, P=101.3, Rh=0.60, duration=Hour(1)),
    Atmosphere(T=25.0, Wind=2.0, P=101.3, Rh=0.55, duration=Hour(1)),
])

applications = (
    ModelSpec(Monteith(); name=:energy_balance) |>
        AppliesTo(Many(scale=:Leaf)),
    ModelSpec(Fvcb(); name=:photosynthesis) |>
        AppliesTo(Many(scale=:Leaf)),
    ModelSpec(Medlyn(0.03, 12.0); name=:stomatal_conductance) |>
        AppliesTo(Many(scale=:Leaf)),
)

scene = CompositeModel(
    Object(:scene; scale=:Scene, kind=:scene),
    Object(:plant; scale=:Plant, kind=:plant, parent=:scene),
    Object(
        :sun_leaf;
        scale=:Leaf,
        kind=:plant,
        parent=:plant,
        status=Status(
            Ra_SW_f=20.0,
            sky_fraction=1.0,
            aPPFD=1500.0,
            d=0.03,
        ),
    ),
    Object(
        :shade_leaf;
        scale=:Leaf,
        kind=:plant,
        parent=:plant,
        status=Status(
            Ra_SW_f=8.0,
            sky_fraction=0.5,
            aPPFD=600.0,
            d=0.02,
        ),
    );
    applications=applications,
    environment=weather,
)

[(id=object.id, aPPFD=object.status.aPPFD) for
 object in model_objects(scene; scale=:Leaf)]
```

`Many(scale=:Leaf)` applies each model once to every leaf. Model parameters are
shared, while the two `Status` objects remain independent. Radiation is held
constant per leaf here; see [Simulation over several time steps](several_simulation.md)
for externally prescribed drivers that vary over time.

For repeated plants, a `CompositeModelTemplate` can share the topology and
default model values while `ObjectInstance` provides plant-local scopes.
Parameters may then be overridden for one instance or one exceptional object
without duplicating the unchanged template.

## Run every leaf over the shared weather

Output retention is explicit. `outputs=:all` is convenient for a small
tutorial; use `OutputRequest` for large plants.

```@example several_objects
simulation = run!(scene; steps=length(weather), outputs=:all)

rows = DataFrame(collect_outputs(simulation; sink=nothing))
leaf_rows = subset(
    rows,
    :application_id => ByRow(==(:energy_balance)),
    :variable => ByRow(in((:Tₗ, :A, :Gₛ, :λE))),
)

leaf_results = unstack(
    select(leaf_rows, :timestep, :object_id, :variable, :value),
    [:timestep, :object_id],
    :variable,
    :value,
)
sort!(leaf_results, [:timestep, :object_id])
```

The `object_id` column associates every value with the leaf that produced it;
object declaration order is not an output contract. The latest state also
remains available on each object:

```@example several_objects
Dict(
    object.id => (Tₗ=object.status.Tₗ, A=object.status.A, Gₛ=object.status.Gₛ)
    for object in model_objects(scene; scale=:Leaf)
)
```

## Select values within a plant

Selectors make cross-object coupling explicit:

- `Self()` means only the object where the consuming application runs.
- `Subtree()` means that object and its descendants. A plant-scale model uses
  `Many(scale=:Leaf, within=Subtree(), var=:A)` to read only its own leaves.
- `SceneScope()` searches the complete scene and is appropriate for a
  scene-scale aggregate.

For example, an input declaration for a plant-scale summary model would be:

```julia
Inputs(
    :leaf_assimilation => Many(
        scale=:Leaf,
        within=Subtree(),
        application=:energy_balance,
        var=:A,
        policy=HoldLast(),
    ),
)
```

Continue with [Whole-plant simulation from an MTG](mtg_simulation.md) to adapt
an existing plant topology to the same applications.
