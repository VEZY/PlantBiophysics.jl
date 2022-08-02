# ComponentModels

[`ComponentModels`](@ref) is a structure used to list the processes and associated models for
generic non-photosynthetic components. It can be any kind of component such as wood, spikelet, soil, rock, or even structures such as nets, floor, wall, roof... The name `ModelList` was chosen not because it is generic, but because it is short, simple and self-explanatory.

## Processes

[`ComponentModels`](@ref) implements two processes:

- `interception <: Union{Missing,AbstractInterceptionModel}`: A radiation interception model;
- `energy_balance <: Union{Missing,AbstractEnergyModel}`: An energy balance model;

...and a `status` field:

- `status <: MutableNamedTuple`: a mutable named tuple to track the status of the component, *i.e.* the variables and their values. Values are set to `-999.99` if not provided as keywords arguments (see examples).

!!! note
    The status field depends on the input models. You can get the variables needed by a model using [`variables`](@ref) on the instantiation of a model. You can also use [`inputs`](@ref) and [`outputs`](@ref) instead.

## Examples

Here's an example instantiation of a [`ComponentModels`](@ref):

```@setup usepkg
using PlantBiophysics
```

```@example usepkg
ComponentModels(energy_balance = Monteith())
```
