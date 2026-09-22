# [Energy balance](@id nrj_page)

A leaf can be warmer or cooler than the surrounding air. Its temperature
depends on the radiation it absorbs, the heat exchanged with the air, and
the energy used to evaporate water. The energy-balance model calculates this
temperature and the associated heat fluxes.

PlantBiophysics provides [`Monteith`](@ref), following Monteith and Unsworth
(2013) with the correction discussed by Schymanski and Or (2017). It combines
with photosynthesis and stomatal conductance to calculate the leaf's carbon,
water, and energy exchanges together.

## [Run a coupled leaf simulation](@id exemple_monteith)

Choose one model for each process and provide the weather, absorbed light,
and leaf dimensions:

```@example energy
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

meteo = Atmosphere(
    T=20.0, Wind=1.0, P=101.3, Rh=0.65, duration=Hour(1),
)
scene = leaf_scene(
    Monteith(),
    Fvcb(),
    Medlyn(g0=0.03, g1=12.0);
    status=Status(
        Ra_SW_f=13.747,
        sky_fraction=1.0,
        aPPFD=1500.0,
        d=0.03,
    ),
    environment=meteo,
)
run!(scene)
leaf = model_object(scene, :leaf)
(
    Rn=leaf.status.Rn, H=leaf.status.H, λE=leaf.status.λE,
    Tₗ=leaf.status.Tₗ, A=leaf.status.A, Gₛ=leaf.status.Gₛ,
)
```

The example prescribes the radiation inputs independently to demonstrate how
to provide them. In an application, derive both from consistent radiation
measurements or a [light-interception model](light.md).

You do not need to supply leaf temperature, assimilation, or stomatal
conductance: these are calculated together. Leaf temperature affects
photosynthesis; stomatal conductance affects water loss and cooling. The
model repeats these calculations until the change in estimated temperature
is small enough, or the maximum number of iterations is reached.

## [Read the outputs](@id outputs_monteith)

| Output | Meaning | Unit |
|:--|:--|:--|
| `Rn` | Net radiation: absorbed shortwave plus net longwave radiation | W m⁻² |
| `H` | Sensible heat exchanged with the air | W m⁻² |
| `λE` | Latent heat associated with water-vapour exchange | W m⁻² |
| `Tₗ` | Leaf temperature | °C |
| `A` | Net CO₂ assimilation | µmol CO₂ m⁻² s⁻¹ |
| `Gₛ` | Stomatal conductance to CO₂ | mol CO₂ m⁻² s⁻¹ |

The energy balance is `Rn = H + λE`. Positive `H` means that the leaf loses
sensible heat to the air; a negative value means it gains heat from the air.
`λE` is an energy flux, not a mass of transpired water. Radiation and heat
fluxes here are expressed per unit reference leaf surface area.

Other outputs include net longwave radiation (`Ra_LW_f`), leaf-surface and
intercellular CO₂ (`Cₛ` and `Cᵢ`), boundary-layer conductances (`Gbₕ` and
`Gbc`), the vapour pressure difference (`Dₗ`), and the iteration counter
(`iter`). Inspect the full list with:

```@example energy
outputs(Monteith())
```

`leaf.status` holds the latest values. Use `run!(scene; outputs=:all)` to
retain output history; the [TL;DR](../getting_started/get_started.md) shows
how to collect the six main outputs in a table for several timesteps.

## [Provide the leaf and weather inputs](@id inputs_monteith)

| Leaf input | Meaning | Unit |
|:--|:--|:--|
| `Ra_SW_f` | Absorbed shortwave radiation, including PAR and near infrared | W m⁻² leaf |
| `sky_fraction` | Combined sky view of both leaf faces | 0–2 |
| `d` | Characteristic leaf dimension, such as leaf width | m |
| `aPPFD` | Absorbed PAR photon flux, needed by `Fvcb` | µmol photons m⁻² leaf s⁻¹ |

The radiation inputs must use the reference leaf surface area. Canopy
radiation per unit ground area needs a conversion before it can drive a leaf;
see [Light interception](light.md).

`sky_fraction=1` represents a leaf whose upper face sees the sky and whose
lower face sees the canopy or ground. Values below one describe a partly
obstructed sky view; two means that both faces see only sky. This controls
longwave radiation exchange. Surrounding objects other than the sky are
assumed to have the same temperature as the leaf, a simplification to keep
in mind when their temperatures differ substantially.

The `Atmosphere` supplies air temperature, humidity, wind speed, pressure,
and atmospheric CO₂, along with quantities calculated by PlantMeteo. See
[Micro-climate](../climate/microclimate.md) for the weather inputs and units.

## [Set the model parameters](@id param_monteith)

| Parameter | Meaning | Default |
|:--|:--|:--|
| `aₛₕ` | Number of leaf faces exchanging sensible heat | `2` |
| `aₛᵥ` | Number of leaf faces exchanging water vapour | `1` |
| `ε` | Leaf emissivity | `0.955` |
| `maxiter` | Maximum number of temperature iterations | `10` |
| `ΔT` | Temperature-change threshold for convergence (°C) | `0.01` |

The default represents a leaf exchanging heat on both faces but water vapour
on one face, as for a hypostomatous leaf. For a leaf with stomata on both
faces, choose `aₛᵥ=2`. These are surface models, so there are at most two faces.

For example, this changes the number of transpiring faces while retaining
the other defaults:

```@example energy
energy_model = Monteith(aₛᵥ=2)
(heat_exchange_faces=energy_model.aₛₕ, transpiring_faces=energy_model.aₛᵥ)
```

Use `energy_model` in place of `Monteith()` in the scene above. The convergence
threshold compares successive estimates **within one timestep**, not the
temperatures of two consecutive weather records.

`Monteith` prefers hourly weather and accepts timesteps from one minute to
two hours. It computes a steady-state balance for the conditions of each
timestep. See [Multi-rate simulation](../simulation/multirate_simulation.md)
for choosing intervals when processes run at different rates.

## Evaluation and references

The [Schymanski et al. evaluation](@ref schymanski-evaluation) compares latent
heat, sensible heat, and net radiation with measurements on an artificial
leaf across wind speeds. Its [standalone wrapper](schymanski.jl) runs the
same scenario and plotting implementation as the numerical regression tests
and documentation. The [Model evaluation](../evaluation.md) page also shows
the coupled model's results against gas-exchange measurements.

The energy-balance formulation follows Monteith and Unsworth (2013),
*Principles of Environmental Physics*, chapter 13, and
[Schymanski and Or (2017)](https://doi.org/10.5194/hess-21-685-2017).
Its implementation is close to the MAESPA formulation described by
[Duursma and Medlyn (2012)](https://doi.org/10.5194/gmd-5-919-2012) and
[Vezy et al. (2018)](https://doi.org/10.1016/j.agrformet.2018.02.005).
