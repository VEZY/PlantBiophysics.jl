# [Energy Balance](@id nrj_page)

[`Monteith`](@ref) solves leaf temperature, latent heat, sensible heat, net
radiation, boundary conductance, photosynthesis, and stomatal conductance
iteratively.

```@example energy
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

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
    environment=Atmosphere(
        T=20.0,
        Wind=1.0,
        P=101.3,
        Rh=0.65,
        duration=Hour(1),
    ),
)

run!(scene)
leaf = only(model_objects(scene; scale=:Leaf))
(Tₗ=leaf.status.Tₗ, Rn=leaf.status.Rn, H=leaf.status.H, λE=leaf.status.λE)
```

`Monteith` controls the call stack. During each temperature iteration it calls
the selected photosynthesis model, which may in turn call stomatal
conductance. These applications are compiled as manual call targets and are
not independently run by the root scheduler.

```@example energy
explain_calls(PlantSimEngine.compile_composite_model(scene))
```

The required timestep range is one minute to two hours, with one hour
preferred:

```@example energy
PlantSimEngine.timestep_hint(Monteith())
```

Important status inputs are absorbed shortwave radiation (`Ra_SW_f`), visible
sky fraction (`sky_fraction`), absorbed PPFD (`aPPFD`), and characteristic leaf
dimension (`d`). Use `inputs(model)` and `outputs(model)` for the complete
contract.
