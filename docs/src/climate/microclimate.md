# [Micro-climate](@id microclimate_page)

```@setup usepkg
using PlantBiophysics, PlantMeteo
```

The micro-climatic/meteorological conditions measured close to the object or component are given as the second argument of the simulation functions shown earlier.

PlantBiophysics usually uses a special data structure from the PlantMeteo package to declare those conditions, and to pre-compute other required variables. This data structure is a type called `Atmosphere`.

The mandatory variables to provide are: `T` (air temperature in °C), `Rh` (relative humidity, 0-1), `Wind` (the wind speed in m s-1) and `P` (the air pressure in kPa).

We can declare such conditions using `Atmosphere` such as:

```@example usepkg
using PlantMeteo
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
```

The `Atmosphere` also computes other variables based on the provided conditions, such as the vapor pressure deficit (VPD) or the air density (ρ). You can also provide those variables as inputs if necessary. For example if you need another way of computing the VPD, you can provide it as follows:

```@example usepkg
using PlantMeteo
Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65, VPD = 0.82)
```

To access the values of the variables after instantiation, we can use the dot syntax. For example if we need the vapor pressure at saturation, we would do as follows:

```@example usepkg
meteo.eₛ
```

See the documentation of the function if you need more information about the variables: `Atmosphere`.

If you want to simulate several time-steps with varying conditions, you can do so by using `Weather` instead of `Atmosphere`.

`Weather` is just an array of `Atmosphere` along with some optional metadata. For example for three time-steps, we can declare it like so:

```@example usepkg
using PlantMeteo
w = Weather(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ],
    (
        site = "Montpellier",
        other_info = "another crucial metadata"
    )
)
```

As you see the first argument is an array of `Atmosphere`, and the second is a named tuple of optional metadata such as the site or whatever you think is important.

A `Weather` can also be declared from a DataFrame, provided each row is an observation from a time-step, and each column is a variable needed for `Atmosphere` (see the help of `Atmosphere` for more details on the possible variables and their units).

Here's an example of using a DataFrame as input:

```@example usepkg
using CSV, DataFrames, PlantMeteo
file = joinpath(dirname(dirname(pathof(PlantMeteo))),"test","data","meteo.csv")
df = CSV.read(file, DataFrame; header=5, skipto = 6, dateformat = "yyyy/mm/dd")
# Select and rename the variables:
select!(df, :date, :temperature => :T, :relativeHumidity => (x -> x ./ 100 ) => :Rh, :wind => :Wind, :atmosphereCO2_ppm => :Cₐ)
df[!,:duration] .= 1800 # Add the time-step duration, 30min

# Make the weather, and add some metadata:
Weather(df, (site = "Aquiares", file = file))
```

One can also directly import the Weather from an [Archimed-ϕ](https://archimed-platform.github.io/archimed-phys-user-doc/)-formatted meteorology file (a csv file optionally enriched with some metadata). In this case, the user can rename and transform the variables from the file to match the names and units needed in PlantBiophysics using a [`DataFrame.jl`](https://dataframes.juliadata.org/stable/)-alike syntax:

```@example usepkg
using Dates, PlantMeteo

meteo = read_weather(
    joinpath(dirname(dirname(pathof(PlantMeteo))),"test","data","meteo.csv"),
    :temperature => :T,
    :relativeHumidity => (x -> x ./100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)
```

## Helper functions

PlantBiophysics provides some helper functions to compute some micro-climate related variables.

Here is a complete list of these functions:

- `vapor_pressure` computes e (kPa), the vapor pressure from the air temperature and the relative humidity
- `e_sat` computes eₛ (kPa), the saturated vapor pressure from the air temperature
- `air_density` computes ρ (kg m-3), the air density from the air temperature, the pressure, and some constants
- `latent_heat_vaporization` computes λ (J kg-1), the latent heat of vaporization from the air temperature and a constant
- `psychrometer_constant` computes γ (kPa K−1), the psychrometer "constant" from the air pressure, the latent heat of vaporization and some constants
- `atmosphere_emissivity(T,e,constants.K₀)` computes ε (0-1), the atmosphere emissivity from the air temperature, the vapor pressure and a constant
- `e_sat_slope` computes Δ (0-1), the slope of the saturation vapor pressure at air temperature, from the air temperature

!!! note
    All constants are found in `Constants`
