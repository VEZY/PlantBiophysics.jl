# Simulation over several components

```@setup usepkg
using PlantBiophysics, PlantSimEngine, PlantMeteo
using Dates, DataFrames
```

## Running the simulation

We saw in the previous sections how to run a simulation over one and several time-steps.

Now it is also very easy to run a simulation for different components by just providing an array of component instead:

```@example usepkg
using PlantBiophysics, PlantSimEngine, PlantMeteo
using Dates, DataFrames

meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

leaf1 = ModelList(
        Monteith(),
        Fvcb(),
        Medlyn(0.03, 12.0),
        status = (Rₛ = 13.747, sky_fraction = 1.0, PPFD = 1500.0, d = 0.03)
    )

leaf2 = ModelList(
        Monteith(),
        Fvcb(),
        Medlyn(0.03, 12.0),
        status = (Rₛ = 10., sky_fraction = 1.0, PPFD = 1250.0, d = 0.02)
    )

run!([leaf1, leaf2], meteo)

DataFrame(Dict("leaf1" => leaf1, "leaf2" => leaf2))
```

Note that we use a `Dict` of components in the call to `DataFrame` because it allows to get a `component` column to retrieve the component in the `DataFrame`, but we could also just use an Array instead.

A simulation over different time-steps would give:

```@example usepkg
meteo =
    read_weather(
        joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv"),
        :temperature => :T,
        :relativeHumidity => (x -> x ./ 100) => :Rh,
        :wind => :Wind,
        :atmosphereCO2_ppm => :Cₐ,
        date_format=DateFormat("yyyy/mm/dd")
    )

leaf1 = ModelList(
        Monteith(),
        Fvcb(),
        Medlyn(0.03, 12.0),
        status = (
            Rₛ = [5., 10., 20.],
            sky_fraction = 1.0,
            PPFD = [500., 1000., 1500.0],
            d = 0.03
        )
    )

leaf2 = ModelList(
        Monteith(),
        Fvcb(),
        Medlyn(0.03, 12.0),
        status = (
            Rₛ = [3., 7., 16.],
            sky_fraction = 1.0,
            PPFD = [400., 800., 1200.0],
            d = 0.03
        )
    )

run!([leaf1, leaf2], meteo)

DataFrame(Dict("leaf1" => leaf1, "leaf2" => leaf2))
```
