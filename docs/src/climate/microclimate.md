# [Micro-climate](@id microclimate_page)

```@setup usepkg
using PlantBiophysics, PlantMeteo, Dates
```

Leaf processes respond to the air temperature, humidity, wind, and CO₂
concentration around the leaf. PlantMeteo describes these conditions with
an `Atmosphere` for one timestep or a `Weather` series for several timesteps.
Pass either one as `environment=meteo` when creating a `CompositeModel`.

## Describe one timestep

Start with the conditions measured near your leaf:

| Input | Meaning | Unit |
|:--|:--|:--|
| `T` | Air temperature | °C |
| `Rh` | Relative humidity | Fraction from 0 to 1 |
| `Wind` | Wind speed | m s⁻¹ |
| `P` | Air pressure | kPa |
| `Cₐ` | Air CO₂ concentration | µmol mol⁻¹ |
| `duration` | Timestep duration | A period such as `Hour(1)` |

`Atmosphere` supplies defaults for optional inputs, including `Cₐ`, but
provide measured values when available. Specify the duration explicitly
when using a time series or calculating totals.

```@example usepkg
using PlantMeteo
meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, duration=Hour(1))
```

`Atmosphere` calculates related quantities such as vapour pressure deficit
(`VPD`, kPa) and air density (`ρ`, kg m⁻³). You can override a derived value
when you have an independent measurement or calculation:

```@example usepkg
using PlantMeteo
Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, VPD=0.82, duration=Hour(1))
```

Read a value with the dot syntax. For example, saturation vapour pressure
(`eₛ`) is in kPa:

```@example usepkg
meteo.eₛ
```

Incident radiation can also be supplied through `Atmosphere`, using
`Ri_PAR_f` and `Ri_NIR_f` in W m⁻². Leaf models need **absorbed** radiation,
which is supplied on the leaf or calculated by a light model. See
[Light interception](../models/light.md) for the distinction.

## Describe changing weather

`Weather` collects consecutive `Atmosphere` values, with optional metadata
such as a site name. Here are three hourly timesteps:

```@example usepkg
using PlantMeteo
w = Weather(
    [
        Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, duration=Hour(1)),
        Atmosphere(T=23.0, Wind=1.5, P=101.3, Rh=0.60, duration=Hour(1)),
        Atmosphere(T=25.0, Wind=3.0, P=101.3, Rh=0.55, duration=Hour(1))
    ],
    (
        site = "Montpellier",
    )
)
```

Use this series as the scene's `environment` and run three steps with
`run!(scene; steps=3, outputs=:all)`. PlantSimEngine reads the corresponding
weather row at each step; the [several-timestep tutorial](../simulation/several_simulation.md)
shows the complete workflow.

## Read a weather table

A `Weather` can also be declared from a DataFrame, provided each row is an observation from a time-step, and each column is a variable needed for `Atmosphere` (see the help of `Atmosphere` for more details on the possible variables and their units).

This example uses a CSV fixture shipped with PlantMeteo. Replace its path
with your own file and match the column names and units to your data.

```@example usepkg
using CSV, DataFrames, PlantMeteo
file = joinpath(pkgdir(PlantMeteo), "test", "data", "meteo.csv")
df = CSV.read(file, DataFrame; header=5, skipto = 6, dateformat = "yyyy/mm/dd")
# Preserve the start time of each observation before selecting columns:
df.date = Date.(df.date) .+ Time.(df.hour_start)
# Select and rename the variables:
select!(df, :date, :temperature => :T, :relativeHumidity => (x -> x ./ 100 ) => :Rh, :wind => :Wind, :atmosphereCO2_ppm => :Cₐ)
df[!, :duration] = fill(Minute(30), nrow(df))

# Make the weather, and add some metadata:
Weather(df, (site = "Aquiares", file = file))
```

The three records retain their start times: 12:00, 12:30, and 13:00 on
12 June 2016. Keeping these timestamps makes it possible to match simulated
outputs to the original measurements.

For an Archimed-ϕ-formatted CSV with metadata, `read_weather` handles the
import directly. The column transformations below convert relative humidity
from percent to a fraction and rename the weather variables:

```@example usepkg
using Dates, PlantMeteo

meteo = read_weather(
    file,
    :temperature => :T,
    :relativeHumidity => (x -> x ./100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)
```

## Helper functions

PlantMeteo also provides functions for individual weather calculations:

- `vapor_pressure` computes e (kPa), the vapor pressure from the air temperature and the relative humidity
- `e_sat` computes eₛ (kPa), the saturated vapor pressure from the air temperature
- `air_density` computes ρ (kg m-3), the air density from the air temperature, the pressure, and some constants
- `latent_heat_vaporization` computes λ (J kg-1), the latent heat of vaporization from the air temperature and a constant
- `psychrometer_constant` computes γ (kPa K−1), the psychrometer "constant" from the air pressure, the latent heat of vaporization and some constants
- `atmosphere_emissivity(T,e,constants.K₀)` computes ε (0-1), the atmosphere emissivity from the air temperature, the vapor pressure and a constant
- `PlantMeteo.e_sat_slope` computes Δ (kPa K⁻¹), the slope of saturation vapour pressure with temperature

!!! note
    All constants are found in `Constants`
