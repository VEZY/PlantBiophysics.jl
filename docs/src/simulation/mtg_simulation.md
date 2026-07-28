# Multiple Objects And Plants

PlantBiophysics does not prescribe plant topology. Create PlantSimEngine
objects directly, or adapt an existing `MultiScaleTreeGraph` once with
`objects_from_mtg` or `CompositeModel(mtg; ...)`.

Model applications select objects independently of their containing plant:

```julia
applications = (
    ModelSpec(Monteith(); name=:energy_balance) |>
        AppliesTo(Many(scale=:Leaf)) |>
        TimeStep(Hour(1)),
    ModelSpec(Fvcb(); name=:photosynthesis) |>
        AppliesTo(Many(scale=:Leaf)) |>
        TimeStep(Hour(1)),
    ModelSpec(Medlyn(0.03, 12.0); name=:stomatal_conductance) |>
        AppliesTo(Many(scale=:Leaf)) |>
        TimeStep(Hour(1)),
)
```

Each leaf owns its own `Status`. Repeated plants can share an
`CompositeModelTemplate` and use `ObjectInstance` for plant-local scopes. Parameters
can be overridden per instance or exceptional object while unchanged plants
share the same model values.

Cross-object aggregation belongs to the consuming application:

```julia
Inputs(
    :leaf_assimilation => Many(
        scale=:Leaf,
        within=Self(),
        var=:A,
    ),
)
```

When this application runs on each plant, `Self()` restricts the selected
leaves to that plant subtree. A scene-scale model uses
`within=SceneScope()` explicitly.

Growth and pruning use `register_object!` and `remove_object!`. PlantSimEngine
refreshes application targets and reference carriers before the next timestep.
