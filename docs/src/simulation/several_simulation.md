# Simulation over several time-steps

```@setup usepkg
using PlantBiophysics, PlantSimEngine, PlantMeteo
using Dates, DataFrames

```

## Running the simulation

We saw in the previous section how to run a simulation over one time step. We can also easily perform computations over several time steps from a weather file:

```@example usepkg
using PlantBiophysics, PlantSimEngine, PlantMeteo
using Dates, DataFrames

meteo =
    read_weather(
        joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv"),
        :temperature => :T,
        :relativeHumidity => (x -> x ./ 100) => :Rh,
        :wind => :Wind,
        :atmosphereCO2_ppm => :Cₐ,
        date_format=DateFormat("yyyy/mm/dd")
    )

leaf = ModelList(
        Monteith(),
        Fvcb(),
        Medlyn(0.03, 12.0),
        status = (
            Ra_SW_f = [5., 10., 20.],
            sky_fraction = 1.0,
            aPPFD = [500., 1000., 1500.0],
            d = 0.03
        )
    )

out_sim = run!(leaf,meteo)

df = PlantSimEngine.convert_outputs(out_sim, DataFrame)
```

The only difference is that we use the `Weather` structure instead of the `Atmosphere`, and that we provide the models inputs as an Array in the status for the ones that change over time.

Then `PlantBiophysics.jl` takes care of the rest and simulate the energy balance over each time-step. Then the output DataFrame has a row for each time-step.

Note that `Weather` is in fact just an array of `Atmosphere`, with some optional metadata attached to it. We could declare one manually either by using an array of `Atmosphere` like so:

```julia
meteo = Weather(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ]
)
```

Or by passing a `DataFrame`:

```julia
using DataFrames

df = DataFrame(
    T = [20.0, 23.0, 25.0],
    Wind = [1.0, 1.5, 3.0],
    P = [101.3, 101.3, 101.3],
    Rh = [0.65, 0.6, 0.55]
)

meteo = Weather(df)
```

You'll have to be careful about the names and the units you are using though, they must match exactly the ones expected for `Atmosphere`. See the documentation of the structure if in doubt.

The status argument of the ModelList can also be provided as a DataFrame, or any other type that implements the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface. Here's an example using a DataFrame:

```@example usepkg
using DataFrames
df = DataFrame(:Ra_SW_f => [13.747, 13.8], :sky_fraction => [1.0, 1.0], :d => [0.03, 0.03], :aPPFD => [1300.0, 1500.0])

m = ModelList(Monteith(), Fvcb(), Medlyn(0.03, 12.0), status=df)
```

Note that computations will be slower, so if performance is an issue, use
`TimeStepTable` instead (or a NamedTuple as shown in the example above).