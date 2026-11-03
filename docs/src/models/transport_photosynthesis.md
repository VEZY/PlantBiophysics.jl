# Photosynthesis with cuticular transport

Use these concrete models to compare electron-transport hypotheses while
keeping stomatal and cuticular gas diffusion explicit. They replace the
conference `FvcbMechanisms` switchboard; no symbol selects the equations
inside a production model.

| Model | Electron transport | Temperature assumption |
|:--|:--|:--|
| [`FvcbMarquez`](@ref) | Nonrectangular FvCB hyperbola | Standard peaked capacity response |
| [`FvcbRectangularMarquez`](@ref) | Rectangular hyperbola | Standard peaked capacity response |
| [`JohnsonBerry`](@ref) | Cyt b₆f capacity and CO₂-dependent ATP coupling | Standard peaked capacity response |
| [`JohnsonBerryThermal`](@ref) | Cyt b₆f capacity and CO₂-dependent ATP coupling | Capacity activation and coupling-efficiency deactivation |

## Run a cuticle-aware leaf

```@example transport_leaf
using PlantBiophysics, PlantMeteo, PlantSimEngine, Dates

scene = CompositeModel(
    Monteith(maxiter=100),
    FvcbRectangularMarquez(base=Fvcb(VcMaxRef=70.0, JMaxRef=120.0)),
    CuticularConductance(Medlyn(g0=0.01, g1=5.5); gcw=0.005);
    status=Status(aPPFD=600.0, Ra_SW_f=110.0, sky_fraction=2.0, d=0.03),
    environment=Atmosphere(T=25.0, Wind=1.0, P=101.3, Rh=0.6,
        Cₐ=400.0, duration=Hour(1)),
)
run!(scene)
leaf = only(model_objects(scene)).status
(A=leaf.A, Gₛ=leaf.Gₛ, Gₗw=leaf.Gₗw, Tₗ=leaf.Tₗ)
```

The numbers illustrate the composition; they are not fitted species values.
The cuticular pathway is included by the normal `CuticularConductance`
constructor. The new photosynthesis family requires an explicit cuticular
provider: bare Medlyn/Tuzet cannot silently disable it. Use
`CuticularConductance(...; gcw=0)` for a deliberate zero-cuticle comparison.
Medlyn, Tuzet or prescribed stomatal conductance can supply the stomatal part. No flags turn gas-transport or temperature hypotheses
on and off. `gcw=0` is the physical zero-cuticle limit, not another model mode.

## Keep carbon and water pathways distinct

`Gₛ` is stomatal conductance to CO₂. `Gₗw` is the sum of stomatal and
cuticular water conductance, before the atmospheric boundary layer.
The cuticular CO₂ path is separate. The coupled solve follows Lamour's
leaf-surface form of the Márquez transport equations, including the ternary
term from **stomatal** water flux. Cuticular water flux is not inserted into
that term. Photosynthesis and conductance are solved together and the
accepted biochemical, diffusion and stomatal-law residuals are checked.

The water-to-CO₂ conversion comes from `Constants().Gsc_to_Gsw` (1.57 in the
current defaults), rather than a second hardcoded 1.6. Previous conference
coefficients need an explicit conversion or refitting. Wrapped stomatal
intercepts and floors remain stomatal CO₂ quantities; see
[the conductance guide](gs.md#include-the-cuticle).

The calculation assumes ambient humidity represents the external
leaf-surface humidity. Monteith retains its ordinary boundary-layer
approximation. This is a leaf-surface implementation, not a complete
replacement for every chamber recalculation or leaf-side term in the
Márquez theory. All conductances must use a consistent leaf-surface basis.
Finite `gm` adds a mesophyll CO₂ conductance; `gm=Inf` assumes Cc=Ci.
The new numerical solver is currently tested with scalar Float32/Float64.
The uncertainty regression continues to use the analytical `Fvcb` path.

## Fit biochemical parameters from chamber data

Use `Evaluation.fit` with `JohnsonBerry`, `JohnsonBerryThermal`,
`FvcbMarquez`, or `FvcbRectangularMarquez`. Like the [FvCB fitting
tutorial](../fitting/parameter_fitting.md), this fit predicts net assimilation
from instrument-reported intercellular CO₂ (`Cᵢ`), measured leaf temperature
(`Tₗ`), and absorbed light (`aPPFD`). It assumes infinite mesophyll
conductance, so chloroplastic CO₂ equals the supplied `Cᵢ`.

### Read and fit an LI-6800 curve

The bundled file is a dynamic CO₂ ramp with nearly constant absorbed light.
It illustrates the import and fitting workflow; agreement with this curve
is not independent validation. For your own experiment, select observations
from one leaf and treatment, check chamber quality flags, and use stabilized
measurements or a correctly processed dynamic response. The required columns
are `A` (µmol CO₂ m⁻² s⁻¹), `Cᵢ` (µmol mol⁻¹), `Tₗ` (°C), and
`aPPFD` (µmol photons m⁻² s⁻¹). `read_licor6800` maps `Qabs` to
`aPPFD`; do not multiply it by leaf absorptance again.

```@example transport_fit
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

file = joinpath(pkgdir(PlantBiophysics), "test", "inputs", "data", "6800.csv")
curve = read_licor6800(file; ntasks=1)

# Keep the photon yield fixed for this single irradiance level.
base = Fvcb(α=0.425)
# Fix Rd at an illustrative value; it is not measured for this leaf.
fitted = Evaluation.fit(
    JohnsonBerryThermal, curve; base, Tᵣ=25.0, RdRef_bound=(0.8, 0.8),
)
```

The result is a named tuple. Both Johnson–Berry variants return
`Cb6fMaxRef`, the cytochrome b₆f capacity. The Márquez variants with FvCB
electron transport return `JMaxRef` instead. These capacities are model
specific; do not substitute one fitted value for the other. By default, the fit retains the reference temperature in
`base` (25 °C for `Fvcb()`). Passing `Tᵣ=nothing` instead uses the mean leaf
temperature. This also changes where the model anchors its default
CO₂ compensation and Michaelis–Menten constants; it is more than a
conversion of the fitted capacities. Use the returned `Tᵣ` in simulation.

### Choose what the curve can constrain

A CO₂ curve that spans Rubisco and electron-transport limitation can constrain
`VcMaxRef` and the model's electron-transport capacity. `RdRef` is also fitted
by default; check whether the low-CO₂ observations constrain it, or fix it
with `RdRef_bound=(r, r)` when an independent respiration estimate `r` is
available. This is respiration in the light, so a dark flux is not a direct
measurement of it. By default, `TPURef` retains the value in `base`. Supply a numeric
`TPURef` starting value to fit it when the high-CO₂ observations show
triose-phosphate-utilization limitation. A plateau alone does not establish
which process is limiting.

Photon yield, curvature, temperature-response coefficients, and
Johnson–Berry ATP-coupling efficiencies remain fixed. Use the model defaults
as starting assumptions, or supply values justified for your leaf and
protocol. A single temperature or irradiance cannot constrain the
corresponding response shape; use dedicated light or temperature series
to evaluate those assumptions. For example, the default `nL_ref=0.75`
and `nC_ref=1.0` are assumptions used by
[Johnson & Berry (2021)](https://doi.org/10.1007/s11120-021-00840-4).
The package's photon-yield and thermal coefficients are fixed model settings,
not universal values or estimates from this curve. The
[Johnson, Field & Berry (2021)](https://doi.org/10.1007/s00442-021-05062-y)
study motivates separating thermal activation from coupling efficiency;
`JohnsonBerryThermal` keeps its own existing coefficient defaults. Pass a configured
model instance as the fit template to preserve custom settings. Finite mesophyll
conductance and stomatal and cuticular conductances are outside this fit.
The latter do not enter the calculation when `Cᵢ` is prescribed; a chamber's
reported `Cᵢ` is itself inferred using its gas-exchange assumptions. At low
stomatal conductance, cuticular water loss can bias this inference if treated
as stomatal flux; see [Lamour et al. (2022)](https://doi.org/10.1111/nph.17762).
This fitter uses the supplied `Cᵢ` as-is; supply independently corrected values
when appropriate.

### Use the parameters in a coupled simulation

Rebuild the model with the fitted capacities and the same fixed assumptions.
Here the stomatal and cuticular values are illustrative, supplied separately
from the biochemical fit. The coupled simulation now predicts `Cᵢ` and leaf
temperature, so its assimilation is not a reproduction of the conditional
curve fit.

```@example transport_fit
photosynthesis = JohnsonBerryThermal(
    base=Fvcb(
        Tᵣ=fitted.Tᵣ, VcMaxRef=fitted.VcMaxRef, RdRef=fitted.RdRef,
        TPURef=fitted.TPURef, α=base.α,
    ),
    Cb6fMaxRef=fitted.Cb6fMaxRef,
)
scene = CompositeModel(
    Monteith(maxiter=100),
    photosynthesis,
    CuticularConductance(Medlyn(g0=0.01, g1=5.5); gcw=0.005);
    status=Status(aPPFD=600.0, Ra_SW_f=110.0, sky_fraction=2.0, d=0.03),
    environment=Atmosphere(T=25.0, Wind=1.0, P=101.3, Rh=0.6,
        Cₐ=400.0, duration=Hour(1)),
)
run!(scene)
leaf = only(model_objects(scene)).status
(; A=leaf.A, Cᵢ=leaf.Cᵢ, Tₗ=leaf.Tₗ)
```

## What the current evaluation supports

A conditional comparison fitted each model's own capacities to high-light
A–Ci points, then predicted lower-light assimilation using instrument-reported
Ci and measured leaf temperature. It tests electron transport, not the
cuticular or stomatal observation operator.

With a fixed effective photon-yield prior α=0.425, 263 held-out observations
from 45 curves gave RMSE values of 2.684 for nonrectangular FvCB, 1.597 for
rectangular FvCB, 1.613 for Johnson–Berry and 1.648 for the revised thermal
response (µmol CO₂ m⁻² s⁻¹). Capacities were fitted for 46 curves; one had
no lower-light evaluation points.

The ranking depends on that prior. A second test selected α from a shared
seven-value grid using only other measurement dates' lower-light data.
All candidates were scored on the same 257 observations from 44 curves
and 13 dates. RMSE was 1.454, 1.425, 1.446 and 1.386, respectively. The
revised Johnson–Berry response had the smallest pooled error, but its
advantage over the rectangular response was only 0.039, and it had the
lower RMSE on only five of 13 dates. These data do not establish a universal
best electron-transport model. No production default is changed on that basis.

The held-out date still supplies high-light points for its local capacity
fit. Dates within a campaign may share trees. Many capacities are weakly
identified or at bounds; neither cuticular conductance nor the thermal law
is identified by these tests. One failed grid fit removed six observations
from every candidate in the second test. A coupled transfer with unchanged
old coefficients is recorded separately and must not be confused with a
refitted comparison.

## References

- Márquez, Stuart-Williams & Farquhar (2021), [gas-exchange theory](https://doi.org/10.1038/s41477-021-00861-w).
- Lamour et al. (2022), [consequences for gas-exchange modeling](https://doi.org/10.1111/nph.17762), and the authors' leaf-surface equation note.
- Johnson & Berry (2021), [Cyt b₆f electron transport](https://doi.org/10.1007/s11120-021-00840-4).
- Johnson, Field & Berry (2021), [temperature response](https://doi.org/10.1007/s00442-021-05062-y).
