# Simulation over several time-steps

```@setup usepkg
using PlantBiophysics
```

## Running the simulation

We saw in the previous section how to run a simulation over one time step. One could make a loop and execute the same code over several time-steps by changing the values at each time-step. But the package implements a more convenient way to do that:

```@example usepkg
w = Weather(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ]
)

leaf = LeafModels(
        energy_balance = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        Rₛ = [5., 10., 20.],
        sky_fraction = 1.0,
        PPFD = [500., 1000., 1500.0],
        d = 0.03
    )

energy_balance!(leaf,w)

DataFrame(leaf)
```

The only difference is that we use the [`Weather`](@ref) structure instead of the [`Atmosphere`](@ref), and that we provide the models inputs as an Array for the ones that change over time. [`Weather`](@ref) is in fact just a array of [`Atmosphere`](@ref), with some optional metadata attached to it.

Then `PlantBiophysics.jl` takes care of the rest and simulate the energy balance over each time-step. Then the output DataFrame has a row for each time-step.
