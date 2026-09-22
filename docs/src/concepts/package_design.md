# Package Design

PlantBiophysics simulates how plants intercept light, exchange heat and water,
and take up CO₂. To make a simulation, you choose the models you need, provide
their parameters and input conditions, then run them and inspect the results.

Three packages work together: **PlantBiophysics** provides the models,
**PlantSimEngine** combines and runs them, and **PlantMeteo** describes the
weather. This page introduces these ideas with a small leaf simulation.

## Processes and models

A **process** is a biological or physical phenomenon, such as photosynthesis.
A **model** is a particular set of equations used to describe that process.
For example, `Fvcb` is a model of C₃ photosynthesis. Several models can describe
the same process, with different assumptions or required inputs.

PlantBiophysics provides models for four processes:

| Process | What it describes | Available models |
|:--|:--|:--|
| [Light interception](../models/light.md) | Radiation absorbed by a canopy | `Beer`, `BeerShortwave` |
| [Energy balance](../models/energy_balance.md) | Leaf temperature and heat exchanges | `Monteith` |
| [Photosynthesis](../models/photosynthesis.md) | CO₂ assimilation | `Fvcb`, `FvcbIter`, `FvcbRaw`, `ConstantA`, `ConstantAGs` |
| [Stomatal conductance](../models/gs.md) | How readily CO₂ passes through stomata | `Medlyn`, `Tuzet`, `ConstantGs` |

The linked pages explain which model to choose and its inputs. You do not
need to simulate all four processes: below, we calculate stomatal conductance
from a supplied assimilation rate. Some models need another model to work;
we return to this in [Combining models](@ref model_coupling_page).

## Choose a model and its parameters

**Parameters** are values that characterize a model and remain fixed during
the simulation. Creating a model sets its parameters; it does not run the
simulation. Here we choose the Medlyn stomatal-conductance model and set its
two main parameters: the intercept `g0` and the slope `g1`.

```@example design
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates, DataFrames

stomata = Medlyn(g0=0.03, g1=12.0)
```

Some models provide defaults, such as `Fvcb()` and `Monteith()`. Parameters
should describe the plant and conditions you study; the values here are
illustrative. See [Parameter fitting](../getting_started/first_fit.md) to
estimate parameters from measurements.

## Provide weather and leaf inputs

An `Atmosphere` describes the weather for one timestep. Here `T` is air
temperature (°C), `Wind` is wind speed (m s⁻¹), `P` is air pressure (kPa), and
`Rh` is relative humidity as a fraction. PlantMeteo also calculates related
quantities, including the air vapour pressure deficit (`VPD`, kPa).

```@example design
meteo = Atmosphere(
    T=20.0, Wind=1.0, P=101.3, Rh=0.65, duration=Hour(1),
)
nothing # hide
```

The model also needs values describing the leaf. Its **status** stores these
input variables and the outputs calculated during the simulation. We supply
net assimilation (`A`, µmol CO₂ m⁻² s⁻¹), leaf-surface CO₂ concentration
(`Cₛ`, µmol mol⁻¹), and the leaf-to-air vapour pressure difference (`Dₗ`, kPa).
Using `meteo.VPD` for `Dₗ` assumes that leaf temperature equals air temperature
in this simple example.

`leaf_scene` assembles a simulation with one leaf, the chosen model, its
initial status, and its weather:

```@example design
scene = leaf_scene(
    stomata;
    status=Status(A=20.0, Cₛ=400.0, Dₗ=meteo.VPD),
    environment=meteo,
)
nothing # hide
```

This `scene` is a PlantSimEngine `CompositeModel`: it brings together the
objects, models, and conditions to simulate. The [Variables](../variables.md)
page lists variable names, meanings, and units; the
[Micro-climate](../climate/microclimate.md) page explains weather inputs.

## Run the simulation and read the results

`run!` runs one timestep by default. It updates the leaf's status and returns
a `Simulation`. Setting `outputs=:all` also records the calculated outputs
so they can be collected afterwards.

```@example design
simulation = run!(scene; outputs=:all)
leaf = model_object(scene, :leaf)
leaf.status.Gₛ
```

The result is stomatal conductance to CO₂ (`Gₛ`, mol CO₂ m⁻² s⁻¹). Here `leaf`
is the object created by `leaf_scene`, and `leaf.status.Gₛ` is its latest value.
Recorded outputs can also be read as a table:

```@example design
results = DataFrame(collect_outputs(simulation; sink=nothing))
select(results, :timestep, :variable, :value)
```

Without `outputs=:all`, the latest values are still available on the leaf,
but output history is not retained by default. To simulate changing weather,
use a `Weather` series and `run!(scene; steps=..., outputs=:all)`, as shown in
[Simulation over several time steps](../simulation/several_simulation.md).

## [Combining models](@id model_coupling_page)

One model's output can be another model's input. In our example, assimilation
`A` is supplied by hand. Combining `Fvcb()` with `Medlyn(...)` instead lets the
models calculate assimilation and stomatal conductance together.

Adding `Monteith()` also calculates leaf temperature and the energy-balance
fluxes. Temperature affects photosynthesis, and stomatal conductance affects
water loss and leaf cooling, so these models must be solved together.
PlantSimEngine connects the models, and PlantBiophysics handles their coupled
calculations. You supply the remaining inputs, such as absorbed light and
leaf dimensions, rather than prescribing the quantities they calculate.

The [TL;DR example](../getting_started/get_started.md) shows this complete
combination and its outputs. Canopy light models need an area conversion
before their results can drive leaf models; the
[Light interception](../models/light.md) page explains that step.

To move beyond a single leaf, see [Several objects](../simulation/several_objects_simulation.md)
and [Whole-plant simulation](../simulation/mtg_simulation.md). To add your own
equations, see [Implement a model](../extending/implement_a_model.md).
