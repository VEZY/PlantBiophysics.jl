# Simulation over several components

```@setup usepkg
using PlantBiophysics
```

## Running the simulation

We saw in the previous sections how to run a simulation over one and several time-steps.

Now it is also very easy to run a simulation for different components by just providing an array of component instead:

```@example usepkg
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

leaf1 = LeafModels(
        energy = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        Rₛ = 13.747, skyFraction = 1.0, PPFD = 1500.0, d = 0.03
    )

leaf2 = LeafModels(
        energy = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        Rₛ = 10., skyFraction = 1.0, PPFD = 1250.0, d = 0.02
    )


energy_balance!([leaf1, leaf2], meteo)

DataFrame(Dict("leaf1" => leaf1, "leaf2" => leaf2))
```

Note that we use a `Dict` of components in the call to `DataFrame` because it allows to get a `component` column to retrieve the component in the `DataFrame`, but we could also just use an Array instead.

And the same simulation over different time-steps would give:

```@example usepkg
w = Weather(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ]
)

leaf1 = LeafModels(
        energy = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        Rₛ = [5., 10., 20.],
        skyFraction = 1.0,
        PPFD = [500., 1000., 1500.0],
        d = 0.03
    )

leaf2 = LeafModels(
        energy = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        Rₛ = [3., 7., 16.],
        skyFraction = 1.0,
        PPFD = [400., 800., 1200.0],
        d = 0.03
    )

energy_balance!([leaf1, leaf2], w)

DataFrame(Dict("leaf1" => leaf1, "leaf2" => leaf2))
```

## Wrap-up

Now that you learned how to run those simulations, you can head to the next section to learn more about the package design to better understand what is a process, a component or a model.
