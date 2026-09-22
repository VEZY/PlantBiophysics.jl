# [Implement a Model](@id model_implementation_page)

You can add an alternative model without changing PlantBiophysics itself.
This tutorial implements a Ball–Berry-style stomatal-conductance model,
then runs it on a leaf.

The process already exists, so our model will inherit from
`AbstractStomatal_ConductanceModel`. A different set of equations for the same
process does not require a new process; see [Implement a process](implement_a_process.md)
when the biological or physical question itself is new.

## Start from the equation

The example uses

```math
G_s = \max\left(g_{s,\min},\; g_0 + g_1\frac{Rh}{C_s}A\right).
```

`A` is net assimilation (µmol CO₂ m⁻² s⁻¹), `Cₛ` is leaf-surface CO₂
concentration (µmol mol⁻¹), and `Rh` is relative humidity as a fraction.
`Gₛ`, `g0`, and `gs_min` are in mol CO₂ m⁻² s⁻¹; `g1` is dimensionless.
Here we use air relative humidity for the humidity term.
The parameter values below are illustrative, not a calibrated species
parameterization, and the conductance convention is for CO₂.

## Store the parameters

A Julia `struct` names the model and stores its fixed parameters:

```@example new_model
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

struct BandB{T} <: AbstractStomatal_ConductanceModel
    g0::T
    g1::T
    gs_min::T
end
```

The parent type identifies the process. `{T}` lets Julia retain the numeric
type of the supplied parameters instead of forcing every value to `Float64`.
We add a keyword constructor that promotes mixed input types to a common type:

```@example new_model
BandB(; g0, g1, gs_min=0.001) = BandB(promote(g0, g1, gs_min)...)
Base.eltype(::BandB{T}) where {T} = T

stomata = BandB(g0=0, g1=2.0)
(process(stomata), stomata.g0, stomata.gs_min)
```

Here the integer `0` becomes `0.0`, and `gs_min` receives its default.

## Declare what the model reads and calculates

The model reads assimilation and surface CO₂ from the leaf's `Status`. It
reads relative humidity from the weather and writes stomatal conductance:

```@example new_model
PlantSimEngine.inputs_(::BandB) = (A=Required(Real), Cₛ=Required(Real))
PlantSimEngine.outputs_(model::BandB) = (Gₛ=zero(model.g0),)
PlantSimEngine.environment_inputs_(::BandB) = (Rh=0.0,)
PlantSimEngine.environment_outputs_(::BandB) = NamedTuple()

(inputs(stomata), environment_inputs(stomata), outputs(stomata))
```

`Required(Real)` means the simulation must supply a numeric value, either
explicitly or from another model. The zero in `outputs_` initializes storage;
`run!` will replace it with the calculated result. The `Rh=0.0` declaration
identifies a required weather field; it does not substitute zero humidity
when weather is missing.

## Implement the calculation

Stomatal models in PlantBiophysics share the calculation
`max(gs_min, g0 + closure * A)`. They provide a `gs_closure` method for the
model-specific multiplier of assimilation. Photosynthesis models can also
use this method while solving assimilation and conductance together.

For our equation, the multiplier is `g1 * Rh / Cₛ`:

```@example new_model
function PlantBiophysics.gs_closure(
    model::BandB, status, environment, constants=nothing, context=nothing,
)
    return model.g1 * environment.Rh / status.Cₛ
end
```

The shared stomatal `run!` method already applies this multiplier and the
minimum conductance, so `BandB` needs no new `run!` method. Prefixing the
function with `PlantBiophysics.` extends the package's function rather than
creating an unrelated function with the same name.

For other processes, implement the one-timestep method yourself:

```julia
function PlantSimEngine.run!(model::YourModel, status, environment, constants, context)
    # Read parameters from model, changing values from status,
    # weather from environment, and physical constants from constants.
    # Assign every output declared in outputs_.
    return nothing
end
```

`YourModel` is a placeholder here. Keep the scientific equations in this
method; PlantSimEngine handles applying them to objects and timesteps.

## Check the equation, then run a simulation

Start with a direct calculation so that you can compare it with the equation:

```@example new_model
meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, duration=Hour(1))
status = Status(A=20.0, Cₛ=400.0, Gₛ=0.0)
run!(stomata, status, meteo, PlantMeteo.Constants(), nothing)
expected = max(stomata.gs_min, stomata.g0 + stomata.g1 * meteo.Rh / status.Cₛ * status.A)
@assert isapprox(status.Gₛ, expected)
status.Gₛ
```

Then assemble the model exactly as you would use a built-in model:

```@example new_model
scene = leaf_scene(
    stomata;
    status=Status(A=20.0, Cₛ=400.0),
    environment=meteo,
)
run!(scene)
model_object(scene, :leaf).status.Gₛ
```

The direct and scene calculations should agree. For a model you intend to
reuse, also test parameter ranges, missing inputs, and the numerical types
that you claim to support. `Authoring.validate_model(stomata)` checks the
model's declarations; it does not validate the biological hypothesis.

## Use it with photosynthesis

The same `BandB` instance can replace `Medlyn` in a coupled leaf example.
Here [`Fvcb`](@ref) supplies assimilation, so we no longer prescribe `A`:

```@example new_model
coupled_scene = leaf_scene(
    Fvcb(),
    stomata;
    status=Status(Tₗ=25.0, aPPFD=1000.0, Cₛ=400.0),
    environment=meteo,
)
run!(coupled_scene)
leaf = model_object(coupled_scene, :leaf)
(A=leaf.status.A, Gₛ=leaf.status.Gₛ, Cᵢ=leaf.status.Cᵢ)
```

This works because `BandB` provides the stomatal methods and fields that
`Fvcb` uses. Sharing an abstract process type alone does not guarantee that
two models are interchangeable: their variables, units, required weather,
and any called models must also agree.

A model that only **reads** another model's output declares that variable in
`inputs_`. A model that **calls** another model during its calculation also
declares the call with `dep`; [`Fvcb`](@ref) and [`Monteith`](@ref) are examples.
Those more advanced calls use `call_model`, `call_targets`, and `run_call!`
from PlantSimEngine, rather than calling a whole simulation again.

For a reusable model, document its units, area basis, assumptions, references,
and supported domain. Where connected models use `VariableContract`, declare
matching physical meanings with `variable_contracts_`; converting units or
area bases should be an explicit model step. The
[light-interception examples](../models/light.md) show why this matters.

The built-in implementations are useful starting points:
[`Medlyn`](@ref) for stomatal conductance, [`FvcbRaw`](@ref) for photosynthesis
without conductance coupling, and [`Monteith`](@ref) for coupled energy balance.
