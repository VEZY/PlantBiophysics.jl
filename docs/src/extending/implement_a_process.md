# Implement a Process

A **process** names the biological or physical phenomenon being simulated;
a **model** supplies one set of equations for it. PlantBiophysics already
defines light interception, energy balance, photosynthesis, and stomatal
conductance. Reuse those processes when adding an alternative equation, as
in [Implement a model](@ref model_implementation_page).

Declare a new process when you introduce a different phenomenon, such as
plant growth. The declaration gives its models a shared identity; it does
not choose their equations or create a simulation.

## Declare the process

PlantSimEngine provides the `@process` macro. The first argument is the
process name and the optional second argument documents its meaning:

```@example new_process
using PlantSimEngine

@process "growth" "Models that calculate plant growth." verbose=false
AbstractGrowthModel
```

This creates `AbstractGrowthModel`, the parent type for implementations of
`growth`. `verbose=false` suppresses the macro's interactive guidance; omit
it when you want that help in a Julia REPL.

## Give a model that identity

A model inherits from the generated type. This small placeholder demonstrates
only the identity; it does not yet implement a growth equation:

```@example new_process
struct GrowthExample <: AbstractGrowthModel end
process(GrowthExample())
```

Before this can run, choose and document the scientific equation, its
parameters, and the meaning and units of its variables. Then add:

- `inputs_` for values read from the simulated object;
- `outputs_` for values calculated by the model;
- `environment_inputs_` if it reads weather or other shared conditions;
- `run!` for the calculation over one timestep.

The [model implementation tutorial](@ref model_implementation_page) walks
through these steps with a working stomatal-conductance model. For a growth
model, also make clear whether an output is a growth **rate**, a biomass
**increment over the timestep**, or a cumulative biomass **state**. Those
quantities require different equations and cannot be exchanged just because
they share a variable name.

Once complete, use the model in a PlantSimEngine `CompositeModel`, selecting
the plant or organ on which it acts. Process declarations do not determine
that selection, and a growth model need not act on a leaf. See
[Whole-plant simulation](../simulation/mtg_simulation.md) for assembling
models on different organs.
