# [Stomatal conductance](@id gs_page)

```@setup usepkg
using PlantBiophysics, PlantSimEngine
```

The stomatal conductance defines the conductance **for CO₂** between the atmosphere (the air around the leaf) and the air inside the stomata. The stomatal conductance to CO₂ and H₂O are related by a constant (see [`gsc_to_gsw`](@ref)).

## Models overview

The stomatal conductance (`Gₛ`, ``mol_{CO_2} \cdot m^{-2} \cdot s^{-1}``) can be simulated using [`stomatal_conductance!`](@ref) or [`stomatal_conductance`](@ref). Several models are available to simulate it:

- [`Medlyn`](@ref): an implementation of the Medlyn et al. (2011) model
- [`ConstantGs`](@ref): a model to force a constant value for `Gₛ`

You can choose which model to use by passing a component with a stomatal conductance model set to one of the `struct` above.

For example, you can "simulate" a constant assimilation for a leaf using the following:

```@example usepkg
using PlantBiophysics, PlantSimEngine

meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = ModelList(stomatal_conductance = ConstantGs(Gₛ = 0.1))

stomatal_conductance!(leaf,meteo)
leaf[:Gₛ]
```

## Medlyn

### [Parameters](@id param_medlyn)

The Medlyn model has the following set of parameters:

- `g0`: intercept (``mol_{CO_2} \cdot m^{-2} \cdot s^{-1}``).
- `g1`: slope.
- `gs_min = 0.001`: residual conductance (``mol_{CO_2} \cdot m^{-2} \cdot s^{-1}``).

!!! note
    We consider the residual conductance being different from `g0` because in practice `g0` can be negative when fitting real-world data.

### [Input variables](@id inputs_medlyn)

The [`Medlyn`](@ref) model needs three input variables:

```@example usepkg
inputs(Medlyn(0.1, 8.0))
```

`Dₗ` (kPa) is the difference between the vapour pressure at the leaf surface and the saturated air vapour pressure, `Cₛ` (ppm) is the stomatal CO₂ concentration, and `A` is the CO₂ assimilation rate (``μmol \cdot m^{-2} \cdot s^{-1}``)

### [Example](@id exemple_medlyn)

Here is an example usage:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = ModelList(
    stomatal_conductance = Medlyn(0.03, 12.0),
    status = (A = 20.0, Cₛ = 400.0, Dₗ = meteo.VPD)
)

stomatal_conductance!(leaf,meteo)

leaf
```

!!! note
    You can use [`inputs`](@ref) to get the variables needed for a given model, e.g.: `inputs(Medlyn(0.03, 12.0))`

## ConstantGs

### [Parameters](@id param_constantgs)

The [`ConstantGs`](@ref) model has the following set of parameters:

- `g0 = 0.0`: intercept (``mol_{CO_2} \cdot m^{-2} \cdot s^{-1}``).
- `Gₛ`: forced stomatal conductance.

This model computes the stomatal conductance using a constant value for the stomatal conductance.

`g0` is only provided for compatibility with photosynthesis models such as [`Fvcb`](@ref) that needs a partial computation of the stomatal conductance at one point:

```julia
(Gₛ - g0) / A
```

### [Input variables](@id inputs_constantgs)

[`ConstantGs`](@ref) doesn't need any input variables.

### [Example](@id exemple_constantgs)

Here is an example usage:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = ModelList(stomatal_conductance = ConstantGs(Gₛ = 0.1))

stomatal_conductance!(leaf,meteo)
leaf[:Gₛ]
```

## References

Medlyn, B. E., E. Dreyer, D. Ellsworth, M. Forstreuter, P. C. Harley, M. U. F. Kirschbaum,
X. Le Roux, et al. 2002. « Temperature response of parameters of a biochemically based model
of photosynthesis. II. A review of experimental data ». Plant, Cell & Environment 25 (9): 1167‑79.
<https://doi.org/10.1046/j.1365-3040.2002.00891.x>.
