# First simulation

```@setup usepkg
using PlantBiophysics, PlantSimEngine
using Dates
```

Make your first simulation for a leaf energy balance, photosynthesis and stomatal conductance altogether with few lines of codes:

```@example usepkg
using PlantBiophysics, PlantSimEngine, Dates

meteo = read_weather(
    joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","meteo.csv"),
    :temperature => :T,
    :relativeHumidity => (x -> x ./100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    :Re_SW_f => :Ri_SW_f,
    date_format = DateFormat("yyyy/mm/dd")
)

leaf = ModelList(
        energy_balance = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 7.0),
        status = (
            Rₛ = meteo[:Ri_SW_f] .* 0.8,
            sky_fraction = 1.0,
            PPFD = meteo[:Ri_SW_f] .* 0.8 .* 0.48 .* 4.57,
            d = 0.03
        )
)

energy_balance!(leaf,meteo)

DataFrame(leaf)
```

Curious to understand more ? Head to the next section to learn more about parameter fitting, or to the [Simple simulation](@ref) section for more details about how to make simulations.
