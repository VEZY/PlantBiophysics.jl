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
PlantSimEngine.inputs_(::ExampleFlux) = (
    driver=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::ExampleFlux) = (flux=0.0,)
```

Use `Required(T)` when object state or another application must supply an
input, and `Default(value)` only for a genuine model fallback. These
declarations are the coupling contract. The model should not know which object,
plant, species, or timestep supplies `driver`.

If the implementation reads sampled forcing directly, declare that separately:

```julia
PlantSimEngine.environment_inputs_(::ExampleFlux) = (T=0.0,)
```

Here `0.0` represents the environment field's schema; it is not a runtime
default. A missing `T` is reported by `validate_environment_inputs` or during
scene compilation, before the numerical method runs. Do not declare a forcing
field that the implementation never reads.

## Implement One Timestep

```julia
function PlantSimEngine.run!(
    model::ExampleFlux,
    status,
    environment,
    constants,
    context=nothing,
)
    status.flux = model.coefficient * status.driver
    return nothing
end
```

Fixed parameters belong in the model. Timestep-varying values belong in
`status` when they describe object state or come from another application.
Sampled meteorological forcing belongs in `environment`, shared physical
constants in `constants`, and each direct environment read must appear in
`environment_inputs_`.

## Manual Dependencies

Declare a hard dependency only when the model calls another model itself:

```julia
PlantSimEngine.dep(::ParentModel) = (
    child=Call(process=:child_process),
)
```

Inside `run!`, retrieve the compiled dependency and execute its targets:

```julia
for target in call_targets(context, :child)
    run_call!(target; sampled_environment=environment, publish=true)
end
```

`call_targets` is always vector-like; use `only(targets)` for a declared `One`
call when exactly one target is required. Iterative models should execute
individual targets with `publish=false` for trials and publish only the
accepted state. Passing `sampled_environment=trial_environment` forwards that sampled or
trial environment directly to the selected target; omit it to use the target's
compiled environment binding.

Value dependencies that the model merely reads are soft dependencies. Declare
the input in `inputs_`; scenario assembly or same-object inference determines
its source.

## Test The Contract

Test:

1. `inputs`, `environment_inputs`, `outputs`, and `process`;
2. direct equations on a minimal `Status`;
3. missing-forcing diagnostics before one-object scene execution;
4. manual call compilation when applicable;
5. generic numeric values when the model claims to support them.
