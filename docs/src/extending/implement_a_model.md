# [Implement A Model](@id model_implementation_page)

A PlantBiophysics model is a generic PlantSimEngine kernel.

## Declare The Process And Type

```julia
PlantSimEngine.@process "example_flux" verbose=false

struct ExampleFlux{T} <: AbstractExample_FluxModel
    coefficient::T
end
```

Keep parameters parametric so users can supply units, dual numbers, or
uncertainty wrappers.

## Declare Variables

```julia
PlantSimEngine.inputs_(::ExampleFlux) = (driver=0.0,)
PlantSimEngine.outputs_(::ExampleFlux) = (flux=0.0,)
```

These declarations are the coupling contract. The model should not know which
object, plant, species, or timestep supplies `driver`.

## Implement One Timestep

```julia
function PlantSimEngine.run!(
    model::ExampleFlux,
    models,
    status,
    meteo,
    constants,
    extra=nothing,
)
    status.flux = model.coefficient * status.driver
    return nothing
end
```

Fixed parameters belong in the model. Timestep-varying values belong in
`status`. Weather belongs in `meteo`.

## Manual Dependencies

Declare a hard dependency only when the model calls another model itself:

```julia
PlantSimEngine.dep(::ParentModel) = (
    child=Call(process=:child_process),
)
```

Inside `run!`, execute the compiled dependency with
`run_call!(extra, :child; meteo=meteo, publish=true)`. This always returns a
vector-like target collection; use `only(targets)` for a declared `One` call.
Iterative models should retrieve `call_targets(extra, :child)`, execute
individual targets with `publish=false` for trials, and publish only the
accepted state.

Value dependencies that the model merely reads are soft dependencies. Declare
the input in `inputs_`; scenario assembly or same-object inference determines
its source.

## Test The Contract

Test:

1. `inputs`, `outputs`, and `process`;
2. direct equations on a minimal `Status`;
3. one-object scene execution;
4. manual call compilation when applicable;
5. generic numeric values when the model claims to support them.
