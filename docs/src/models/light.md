# [Light Interception](@id light_page)

PlantBiophysics provides two Beer-Lambert implementations:

- [`Beer`](@ref) computes absorbed photosynthetic photon flux density
  (`aPPFD`);
- [`BeerShortwave`](@ref) also computes absorbed shortwave radiation
  (`Ra_SW_f`) for energy-balance models.

```@example light
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

scene = leaf_scene(
    BeerShortwave(0.6);
    status=Status(LAI=2.0),
    environment=Atmosphere(
        T=20.0,
        Wind=1.0,
        P=101.3,
        Rh=0.65,
        Ri_PAR_f=300.0,
        Ri_SW_f=650.0,
        duration=Hour(1),
    ),
)

run!(scene)
leaf = only(model_objects(scene; scale=:Leaf))
(aPPFD=leaf.status.aPPFD, Ra_SW_f=leaf.status.Ra_SW_f)
```

For geometrically explicit plants, radiation interception is normally computed
by a dedicated 3D radiation package and supplied to PlantBiophysics leaf
models through object status or compiled `ModelSpec(...; inputs=...)`
bindings.
