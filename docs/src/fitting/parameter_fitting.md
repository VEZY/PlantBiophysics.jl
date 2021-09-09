# Parameter fitting

```@setup usepkg
using PlantBiophysics
```

## The fit method

The package provides a generic [`fit`](@ref) function to calibrate a model to user data.

The generic function takes several parameters:

- the model type, *e.g.* `FvCB`*
- a `DataFrame` of the needed data that depends on the given method
- keyword arguments that also depend on the fit method

## Example with FvCB

A fit method is provided by the package to calibrate the parameters of the FvCB model.

For example we provide a method to fit the parameters from the Farquhar et al. (1980) model. Here is an example usage:

```@example usepkg
using PlantBiophysics, Plots, DataFrames

df = read_walz(joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P1F20129.csv"))
# Removing the Rh and light curves for the fitting because temperature varies
filter!(x -> x.curve != "Rh Curve" && x.curve != "ligth Curve", df)

# Fit the parameter values:
VcMaxRef, JMaxRef, RdRef, TPURef = fit(Fvcb, df; Tᵣ = 25.0)
```

## Wrap-up

We learned to make a simple parameter fitting. For more information, you can head over the [Parameter fitting](@ref) section where we present how to check the parameter fitting.
