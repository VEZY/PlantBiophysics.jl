# First Simulation

This tutorial calculates the temperature, photosynthesis, and heat exchanges
of one leaf under a single set of weather conditions. We will choose three
models, provide the weather and leaf inputs, then inspect the results.

## Describe the weather

`Atmosphere` holds the conditions around the leaf for one timestep. Air
temperature `T` is in °C, wind speed `Wind` in m s⁻¹, and pressure `P` in kPa.
Relative humidity `Rh` is a fraction: `0.45` means 45%.

```@example first_simulation
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates, DataFrames

meteo = Atmosphere(
    T=22.0,
    Wind=0.8333,
    P=101.325,
    Rh=0.45,
    duration=Hour(1),
)
```

PlantBiophysics supplies the models, PlantMeteo supplies `Atmosphere`, and
PlantSimEngine combines and runs them. The one-hour `duration` describes the
interval represented by this weather. The leaf models calculate fluxes for
these conditions, rather than totals accumulated over the hour.

## Choose models and leaf inputs

We combine `Monteith()` for energy balance, `Fvcb()` for photosynthesis, and
`Medlyn(0.03, 12.0)` for stomatal conductance. `Monteith()` and `Fvcb()` use
their default parameters; the two Medlyn arguments set `g0` and `g1`.
These values illustrate the workflow and should be adapted to your plant.

The models also need four leaf inputs:

| Input | Meaning | Unit |
|:--|:--|:--|
| `Ra_SW_f` | Absorbed shortwave radiation per unit leaf area | W m⁻² |
| `aPPFD` | Absorbed photosynthetic photon flux per unit leaf area | µmol photons m⁻² s⁻¹ |
| `sky_fraction` | Fraction of the sky visible from the leaf | 0–1 |
| `d` | Characteristic leaf dimension used for boundary-layer exchange | m |

`leaf_scene` creates a simulation containing one leaf. Its `Status` stores
these inputs and the values the models will calculate.

```@example first_simulation
scene = leaf_scene(
    Monteith(),
    Fvcb(),
    Medlyn(0.03, 12.0);
    status=Status(
        Ra_SW_f=13.747,
        sky_fraction=1.0,
        aPPFD=1500.0,
        d=0.03,
    ),
    environment=meteo,
)
nothing # hide
```

The models work together: leaf temperature affects photosynthesis, while
stomatal conductance affects water loss and leaf cooling. You do not need to
choose their order or write an iteration loop. See the
[model pages](../models/energy_balance.md) for equations and parameter details.

## Run the simulation

`run!` computes one timestep by default. `outputs=:all` asks it to save the
calculated values for later analysis. The latest results are also available
directly on the leaf:

```@example first_simulation
simulation = run!(scene; outputs=:all)
leaf = only(model_objects(scene; scale=:Leaf))
(Rn=leaf.status.Rn, H=leaf.status.H, λE=leaf.status.λE,
 Tₗ=leaf.status.Tₗ, A=leaf.status.A, Gₛ=leaf.status.Gₛ)
```

`Rn`, `H`, and `λE` are net radiation, sensible heat flux, and latent heat
flux (W m⁻²). `Tₗ` is leaf temperature (°C), `A` is net CO₂ assimilation
(µmol CO₂ m⁻² s⁻¹), and `Gₛ` is stomatal conductance to CO₂
(mol CO₂ m⁻² s⁻¹). These fluxes are expressed per unit leaf area.

## Collect the results in a table

`collect_outputs` retrieves the saved values. Each row contains one variable
at one timestep; here we select the six results above:

```@example first_simulation
rows = collect_outputs(simulation; sink=DataFrame)
results = subset(
    rows,
    :application_id => ByRow(==(:energy_balance)),
    :variable => ByRow(in((:Rn, :H, :λE, :Tₗ, :A, :Gₛ))),
)
select(results, :timestep, :variable, :value)
```

All six values are saved under `:energy_balance` because `Monteith` calls the
photosynthesis and stomatal models during its calculations.

Continue with [Simulation over several time steps](several_simulation.md)
to supply changing weather, save a time series, and plot the results.
