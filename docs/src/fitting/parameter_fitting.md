# [Parameter Fitting](@id parameter_fitting_page)

PlantBiophysics implements `PlantSimEngine.fit` methods for selected models.
Fitting consumes tabular observations and returns a named tuple of parameters.

## Beer Extinction Coefficient

```@example fitting
using PlantBiophysics, PlantSimEngine, DataFrames

observations = DataFrame(
    LAI=[1.0, 2.0, 3.0],
    Ri_PAR_f=[300.0, 300.0, 300.0],
    aPPFD=[480.0, 770.0, 940.0],
)

fit(Beer, observations)
```

## Model Validation

Use the fitted parameters to construct a new scene. For observations with
different drivers, build and run one leaf scene per observation:

```julia
predictions = map(eachrow(observations)) do row
    scene = leaf_scene(
        Beer(fitted.k);
        status=Status(LAI=row.LAI),
        environment=Atmosphere(
            T=25.0,
            Wind=1.0,
            P=101.3,
            Rh=0.5,
            Ri_PAR_f=row.Ri_PAR_f,
        ),
    )
    run!(scene)
    only(model_objects(scene; scale=:Leaf)).status.aPPFD
end
```

`fit(Fvcb, data)` and `fit(Medlyn, data)` use the same interface. Consult their
docstrings for required columns and optional fitting parameters.
