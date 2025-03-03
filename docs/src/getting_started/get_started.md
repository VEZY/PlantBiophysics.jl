# First simulation

```@setup usepkg
using PlantBiophysics, PlantSimEngine, PlantMeteo
using Dates, DataFrames
```

Make your first simulation for a leaf energy balance, photosynthesis and stomatal conductance altogether with few lines of codes:

```@example usepkg
using PlantBiophysics, PlantSimEngine, PlantMeteo
using Dates, DataFrames

meteo = read_weather(
    joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv"),
    :temperature => :T,
    :relativeHumidity => (x -> x ./100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    :Re_SW_f => :Ri_SW_f,
    date_format = DateFormat("yyyy/mm/dd")
)

leaf = ModelList(
        Monteith(),
        Fvcb(),
        Medlyn(0.03, 7.0),
        status = (
            Ra_SW_f = meteo[:Ri_SW_f] .* 0.8,
            sky_fraction = 1.0,
            aPPFD = meteo[:Ri_SW_f] .* 0.8 .* 0.48 .* 4.57,
            d = 0.03
        )
)

out_sim = run!(leaf,meteo)

df = PlantSimEngine.convert_outputs(out_sim, DataFrame)
```

Curious to understand more ? Head to the next section to learn more about parameter fitting, or to the [Simple simulation](@ref) section for more details about how to make simulations.
