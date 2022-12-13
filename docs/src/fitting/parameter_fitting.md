# Parameter fitting

```@setup usepkg
using PlantBiophysics, PlantSimEngine
```

## The fit method

The package provides a generic [`fit`](@ref) function to calibrate a model using user data.

The generic function takes several parameters:

- the model type, *e.g.* `FvCB`
- a `DataFrame` with the data (depends on the given method)
- keyword arguments (also depend on the fit method)

## Example with FvCB

A fit method is provided by the package to calibrate the parameters of the `FvCB` model (Farquhar et al., 1980).

Here is an example usage from the documentation of the method:

```@example usepkg
using PlantBiophysics, PlantSimEngine
using DataFrames, Plots

df = read_walz(joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P1F20129.csv"))
# Removing the Rh and light curves for the fitting because temperature varies
filter!(x -> x.curve != "Rh Curve" && x.curve != "ligth Curve", df)

# Fit the parameter values:
VcMaxRef, JMaxRef, RdRef, TPURef = fit(Fvcb, df; Tᵣ = 25.0)
```

Now that our parameters are optimized, we can check how close to the data a simulation would get.

First, let's select only the data used for the CO₂ curve:

```@example usepkg
# Checking the results:
filter!(x -> x.curve == "CO2 Curve", df)
nothing # hide
```

Now let's re-simulate the assimilation with our optimized parameter values:

```@example usepkg
leaf =
    ModelList(
        photosynthesis = FvcbRaw(VcMaxRef = VcMaxRef, JMaxRef = JMaxRef, RdRef = RdRef, TPURef = TPURef),
        status = (Tₗ = df.Tₗ, PPFD = df.PPFD, Cᵢ = df.Cᵢ)
    )
photosynthesis!(leaf)
df_sim = DataFrame(leaf);
```

Finally, we can make an A-Cᵢ plot using our custom `ACi` structure as follows:

```@example usepkg
aci = PlantBiophysics.ACi(VcMaxRef, JMaxRef, RdRef, df[:,:A], df_sim[:,:A], df[:,:Cᵢ], df_sim[:,:Cᵢ])
plot(aci, leg=:bottomright)
```

Our simulation fits very closely the observations, nice!

There are another implementation of the FvCB model in our package. One that couples the photosynthesis with the stomatal conductance. And this one computes Cᵢ too. Let's check if it works with this one too by using dummy parameter values for the conductance model:

```@example usepkg
leaf = ModelList(
        photosynthesis = Fvcb(VcMaxRef = VcMaxRef, JMaxRef = JMaxRef, RdRef = RdRef, Tᵣ = 25.0, TPURef = TPURef),
        stomatal_conductance = Medlyn(0.03, 12.),
        status = (Tₗ = df.Tₗ, PPFD = df.PPFD, Cₛ = df.Cₐ, Dₗ = 0.1)
    )

w = Weather(select(df, :T, :P, :Rh, :Cₐ, :T => (x -> 10) => :Wind))
photosynthesis!(leaf, w)
df_sim2 = DataFrame(leaf)

aci2 = PlantBiophysics.ACi(VcMaxRef, JMaxRef, RdRef, df[:,:A], df_sim2[:,:A], df[:,:Cᵢ], df_sim2[:,:Cᵢ])
plot(aci2, leg = :bottomright)
```

We can see the results differ a bit, but it is because we add a lot more computation here, hence adding some degrees of liberty.
