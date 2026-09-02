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

## Variable Ownership

Keep each value in the contract that owns its lifecycle:

- `inputs_` declares object state read through `status`, including values bound
  from another application;
- `environment_inputs_` declares forcing read directly through `environment`;
- model fields hold fixed parameters, while the `constants` argument holds
  shared physical constants;
- `dep` declares hard calls that a model invokes itself;
- distributed outputs remain outputs of their producer application and are
  connected with `ModelSpec(...; inputs=...)` or `outputs_to=...`. They do not
  become meteorological inputs merely because they vary over time.

The values in `environment_inputs_` are schema representatives, not fallback
forcing. PlantSimEngine validates their names against the bound environment
before numerical execution. For example, `Beer` declares `Ri_PAR_f`, while
`Monteith` declares the meteorological fields used by its energy-balance loop.

## Soft Value Dependencies

When one application produces a variable consumed by another application on
the same object, PlantSimEngine infers the value binding when it is unique.
Cross-object values are declared explicitly with
`ModelSpec(...; inputs=...)`.

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

`leaf_scene(models...; status, environment, timestep, type_promotion,
status_transform)` is the convenience API for one leaf. It delegates to
PlantSimEngine's concise `CompositeModel` constructor after preparing
PlantBiophysics model defaults. Larger simulations use PlantSimEngine directly:

```julia
ModelSpec(model; name=:application, on=Many(scale=:Leaf), every=Dates.Hour(1))
```

Plant architecture and scene composition remain outside PlantBiophysics.
