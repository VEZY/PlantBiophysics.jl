# Uncertainty Propagation

PlantBiophysics model parameters and status values are generic. Uncertainty
wrappers can therefore propagate through a scene when the wrapped numeric type
supports the required arithmetic.

```@example uncertainty
using MonteCarloMeasurements
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

assimilation = 25.0 ± 2.0
scene = leaf_scene(
    ConstantA(assimilation);
    status_transform=(variable, value) ->
        variable === :A ? assimilation : value,
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

The `status_transform` call materializes the `A` carrier with the same particle
type as the model parameter before execution. For a general conversion such as
`Float64` to `Float32`, use
`type_promotion=Dict(Float64 => Float32)` instead. These policies convert status
values, input defaults, and output defaults; they do not convert model
parameters or meteorological values.

For automatic differentiation, use dual-valued parameters or status inputs and
ensure every equation in the selected model path supports that type.
