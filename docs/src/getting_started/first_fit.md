# First Parameter Fit

Model parameters should describe the leaves you study. This example estimates
four photosynthesis parameters from gas-exchange measurements using
`Evaluation.fit`, then puts the fitted values into a model.

We use a WALZ GFS-3000 file included with PlantBiophysics, so no download is
needed. The file contains several response curves; we keep the same selection
as the fitting example provided with the package.

```@example first_fit
using PlantBiophysics, PlantSimEngine, DataFrames

file = joinpath(pkgdir(PlantBiophysics), "test", "inputs", "data", "P1F20129.csv")
observations = read_walz(file; ntasks=1)
filter!(row -> row.curve ∉ ("Rh Curve", "ligth Curve"), observations)
first(select(observations, :Tₗ, :aPPFD, :Cᵢ, :A), 5)
```

The spelling `"ligth Curve"` is the label in this file. Each retained row
provides leaf temperature (`Tₗ`, °C), absorbed photon flux (`aPPFD`,
µmol photons m⁻² s⁻¹), intercellular CO₂ concentration (`Cᵢ`, µmol mol⁻¹),
and measured net assimilation (`A`, µmol CO₂ m⁻² s⁻¹).

Now fit the Farquhar–von Caemmerer–Berry model, with parameter values expressed
at a reference temperature of 25 °C:

```@example first_fit
fitted = Evaluation.fit(Fvcb, observations; Tᵣ=25.0)
```

The result contains `VcMaxRef` (Rubisco capacity), `JMaxRef` (electron-transport
capacity), `RdRef` (respiration in the light), `TPURef` (triose-phosphate
utilization), and the chosen reference temperature `Tᵣ`.

The returned names match the model's keyword arguments. The `...` below passes
each fitted value to its corresponding argument:

```@example first_fit
photosynthesis = FvcbRaw(; fitted...)
(VcMaxRef=photosynthesis.VcMaxRef, Tᵣ=photosynthesis.Tᵣ)
```

`FvcbRaw` predicts assimilation from measured `Cᵢ`, which is also how this fit
is evaluated. Continue with the [parameter-fitting tutorial](@ref parameter_fitting_page)
to run the fitted model against the measurements, plot the response curve,
and compare it with the coupled photosynthesis–conductance model.
