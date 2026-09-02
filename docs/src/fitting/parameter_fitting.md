# [Parameter Fitting](@id parameter_fitting_page)

PlantBiophysics implements `PlantSimEngine.Evaluation.fit` methods for selected models.
Fitting consumes tabular observations and returns a named tuple of parameters.

## Beer Extinction Coefficient

```@example fitting
using PlantBiophysics, PlantSimEngine, PlantSimEngine.Evaluation, DataFrames

observations = DataFrame(
    LAI=[1.0, 2.0, 3.0],
    Ri_PAR_f=[300.0, 300.0, 300.0],
    aPPFD=[480.0, 770.0, 940.0],
)

fitted = Evaluation.fit(Beer, observations)
```

`Ri_PAR_f` and `aPPFD` are both expressed per unit ground area in this canopy
fit. `LAI` is leaf area per unit ground area.

## Model Validation

Use the fitted parameters to construct a new scene. For observations with
different drivers, build and run one Plant-scale canopy scene per observation:

```julia
predictions = map(eachrow(observations)) do row
    scene = CompositeModel(
        Object(:plant; scale=:Plant, status=Status(LAI=row.LAI));
        applications=(
            ModelSpec(
                Beer(fitted.k);
                name=:canopy_light,
                on=One(scale=:Plant),
            ),
        ),
        environment=Atmosphere(
            T=25.0,
            Wind=1.0,
            P=101.3,
            Rh=0.5,
            Ri_PAR_f=row.Ri_PAR_f,
        ),
    )
    run!(scene)
    model_object(scene, :plant).status.aPPFD
end
```

`Evaluation.fit(Fvcb, data)` and `Evaluation.fit(Medlyn, data)` use the same interface. Consult their
docstrings for required columns and optional fitting parameters.
