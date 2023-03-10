# First parameter fitting

```@setup usepkg
using PlantBiophysics, PlantSimEngine
```

Parameter fitting is also at the heart of the package, because why making a simulation without good parameter values?

The package provides a [`fit`](@ref) method that helps fitting model parameters to data.

For example we provide a method to fit the parameters from the Farquhar et al. (1980) model ([`Fvcb`](@ref)). Here is an example usage:

```@example usepkg
using PlantBiophysics, PlantSimEngine, DataFrames

df = read_walz(joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P1F20129.csv"))
# Removing the Rh and light curves for the fitting because temperature varies
filter!(x -> x.curve != "Rh Curve" && x.curve != "ligth Curve", df)

# Fit the parameter values:
VcMaxRef, JMaxRef, RdRef, TPURef = fit(Fvcb, df; Tᵣ = 25.0)
```

The fitting method uses the leaf temperature (`Tₗ`, °C), the Photosynthetic Photon Flux Density (`PPFD`, μmol m⁻² s⁻¹) and the intercellular CO₂ concentration (`Cᵢ`, ppm) from the data to fit the four main parameters of the model.

## Wrap-up

We learned to make a simple parameter fitting. For more information, you can head over the [Parameter fitting](@ref) section.
