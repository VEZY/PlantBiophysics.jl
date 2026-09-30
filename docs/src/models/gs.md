# [Stomatal conductance](@id gs_page)

Stomatal conductance describes how readily gases pass between the leaf surface
and the air spaces inside the leaf. PlantBiophysics calculates conductance
**to CO₂**, `Gₛ`, in mol CO₂ m⁻² s⁻¹. Stomata also control water loss, which is
why this process matters for both photosynthesis and leaf cooling.

## Choose a model

| Model | Use it to… | Inputs to supply when run alone |
|:--|:--|:--|
| [`Medlyn`](@ref) | Describe the response to assimilation, CO₂, and air dryness. | `A`, `Cₛ`, `Dₗ` |
| [`Tuzet`](@ref) | Include stomatal closure as leaf water potential decreases. | `A`, `Cₛ`, `Ψₗ` |
| [`ConstantGs`](@ref) | Prescribe a measured conductance or make a controlled comparison. | None |

The examples below run each model alone with prescribed assimilation.
In a [photosynthesis simulation](photosynthesis.md), `Fvcb` calculates
assimilation and stomatal conductance together, so you do not supply `A`.

## [Run the Medlyn model](@id exemple_medlyn)

Choose the model parameters, set the weather, and provide the leaf inputs:

```@example gs
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

meteo = Atmosphere(
    T=20.0, Wind=1.0, P=101.3, Rh=0.65, duration=Hour(1),
)
stomata = Medlyn(g0=0.03, g1=12.0)
scene = CompositeModel(
    stomata;
    status=Status(A=20.0, Cₛ=400.0, Dₗ=meteo.VPD),
    environment=meteo,
)
run!(scene)
leaf = only(model_objects(scene))
leaf.status.Gₛ
```

The result is conductance to CO₂. If you need conductance to water vapour in
the same molar units, use the conversion function:

```@example gs
(CO₂=leaf.status.Gₛ, H₂O=PlantBiophysics.gsc_to_gsw(leaf.status.Gₛ))
```

Do not directly compare `Gₛ` to a gas-exchange instrument's conductance without
checking which gas and units the instrument reports.

### [Parameters](@id param_medlyn)

| Parameter | Meaning | Unit |
|:--|:--|:--|
| `g0` | Intercept of the conductance response | mol CO₂ m⁻² s⁻¹ |
| `g1` | Sensitivity of conductance to assimilation and vapour pressure difference | kPa¹ᐟ² |
| `gs_min` | Minimum permitted conductance; default `0.001` | mol CO₂ m⁻² s⁻¹ |

`g0` and `gs_min` are separate because a fitted intercept can be negative,
while the calculated conductance still needs a lower bound. The example
parameter values are illustrative; see
[Parameter fitting](../fitting/parameter_fitting.md) to estimate them from data.

### [Inputs](@id inputs_medlyn)

| Input | Meaning | Unit |
|:--|:--|:--|
| `A` | Net CO₂ assimilation | µmol CO₂ m⁻² s⁻¹ |
| `Cₛ` | CO₂ concentration at the leaf surface | µmol mol⁻¹ (ppm) |
| `Dₗ` | Leaf-to-air vapour pressure difference | kPa |

The example uses air `VPD` for `Dₗ`, assuming leaf and air temperatures are
equal. With an [energy-balance model](energy_balance.md), leaf temperature and
`Dₗ` are calculated together. You can inspect the model's declarations with:

```@example gs
(inputs=inputs(stomata), outputs=outputs(stomata))
```

## Include leaf water stress with Tuzet

The Tuzet model uses leaf water potential `Ψₗ` (MPa) to reduce conductance as
the leaf dries. You must provide that potential, either from measurements or
from another model; choosing `Tuzet` does not itself simulate plant hydraulics.

Besides `g0`, `g1`, and `gs_min`, its parameters are:

| Parameter | Meaning | Unit |
|:--|:--|:--|
| `Ψᵥ` | Water-potential parameter setting the location of the closure response | MPa |
| `sf` | Steepness of the response to water potential | MPa⁻¹ |
| `Γ` | CO₂ compensation point used in the conductance response | µmol mol⁻¹ |

`g1` is dimensionless in this model; its value is not interchangeable with
the Medlyn `g1`. Supply assimilation and surface CO₂ as before, replacing
`Dₗ` with `Ψₗ`:

```@example gs
tuzet_scene = CompositeModel(
    Tuzet(g0=0.03, g1=12.0, Ψᵥ=-1.5, sf=2.0, Γ=30.0);
    status=Status(A=20.0, Cₛ=400.0, Ψₗ=-1.0),
    environment=meteo,
)
run!(tuzet_scene)
only(model_objects(tuzet_scene)).status.Gₛ
```

For positive assimilation and the same other inputs, a more negative `Ψₗ`
reduces the water-potential response and hence conductance. The [`Tuzet`](@ref)
reference gives the response function.

## [Prescribe a constant conductance](@id exemple_constantgs)

`ConstantGs` sets the conductance directly. For example, to use a measured
value of 0.1 mol CO₂ m⁻² s⁻¹:

```@example gs
constant_scene = CompositeModel(ConstantGs(Gₛ=0.1); environment=meteo)
run!(constant_scene)
only(model_objects(constant_scene)).status.Gₛ
```

Its `Gₛ` parameter is the prescribed conductance; the optional `g0` parameter
defaults to zero and supports coupling with photosynthesis. The model needs
no input variables when run alone. Prescribing measured conductance is useful
when evaluating photosynthesis or energy balance independently of a stomatal
model, as in the [daily evaluation](../evaluation.md#Daily-evaluation).

## Time resolution and references

Stomatal-conductance models prefer an hourly timestep and accept timesteps
from one minute to six hours. See
[Multi-rate simulation](../simulation/multirate_simulation.md) to set the
simulation intervals explicitly.

The models follow [Medlyn et al. (2011)](https://doi.org/10.1111/j.1365-2486.2010.02375.x),
*Reconciling the optimal and empirical approaches to modelling stomatal
conductance*, and Tuzet, Perrier and Leuning (2003), *A coupled model of
stomatal conductance, photosynthesis and transpiration*, Plant, Cell &
Environment 26(7), 1097–1116.
