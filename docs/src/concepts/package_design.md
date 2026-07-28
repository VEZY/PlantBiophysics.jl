# Package Design

PlantBiophysics owns scientific model kernels. PlantSimEngine owns scenario
assembly, dependency compilation, scheduling, object selection, environments,
and output retention.

Each model declares:

- a process identity;
- `inputs_` and `outputs_`;
- optional meteorology inputs;
- optional model-author dependency defaults through `dep`;
- one-timestep equations through `run!`.

The same kernel can therefore run on one leaf or on millions of leaves without
knowing its plant, species, timestep, or coupling context.

## Soft Value Dependencies

When one application produces a variable consumed by another application on
the same object, PlantSimEngine infers the value binding when it is unique.
Cross-object values are declared explicitly with `Inputs(...)`.

## Manual Calls

Some PlantBiophysics models control an iterative call stack:

- `Monteith` calls a photosynthesis model while solving leaf temperature;
- `Fvcb`, `FvcbIter`, and `ConstantAGs` call stomatal conductance.

These are `Call(...)` defaults returned by `dep(model)`. PlantSimEngine
compiles them to concrete call targets. The parent model decides when to call
them and when an accepted result should be published.

## State And Generic Values

Runtime variables live in `Status`. Same-rate coupling uses shared references
where possible, and multi-object inputs use reference vectors. PlantBiophysics
does not require `Float64`; units, dual numbers, and uncertainty wrappers can
flow through models when their operations are defined.

## Scenario Assembly

`leaf_scene(models...; status, environment, timestep)` is the convenience API
for one leaf. It delegates to PlantSimEngine's concise
`CompositeModel(models...; status, id, scale, kind, environment, timestep)` constructor
after preparing PlantBiophysics model defaults. Larger simulations use
PlantSimEngine directly:

```julia
ModelSpec(model; name=:application) |>
    AppliesTo(Many(scale=:Leaf)) |>
    TimeStep(Dates.Hour(1))
```

Plant architecture and scene composition remain outside PlantBiophysics.
