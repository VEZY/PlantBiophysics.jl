# Uncertainty Propagation

PlantBiophysics model parameters and status values are generic. Uncertainty
wrappers can therefore propagate through a scene when the wrapped numeric type
supports the required arithmetic.

```julia
using MonteCarloMeasurements
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

scene = leaf_scene(
    ConstantA(25.0 ± 2.0);
    environment=Atmosphere(
        T=25.0,
        Wind=1.0,
        P=101.3,
        Rh=0.5,
        duration=Hour(1),
    ),
)

run!(scene)
only(model_objects(scene; scale=:Leaf)).status.A
```

The same principle applies to parameters, meteorological variables, and
initialized status fields. PlantSimEngine's reference carriers do not convert
values to `Float64`.

For automatic differentiation, use dual-valued parameters or status inputs and
ensure every equation in the selected model path supports that type.
