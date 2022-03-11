# [Micro-climate](@id microclimate_page)

The micro-climatic/meteorological conditions measured close to the object or component are given as the second argument of the simulation functions shown earlier.

PlantBiophysics provides its own data structure to declare those conditions, and to pre-compute other required variables. This data structure is a type called [`Atmosphere`](@ref).

The mandatory variables to provide are: `T` (air temperature in °C), `Rh` (relative humidity, 0-1), `Wind` (the wind speed in m s-1) and `P` (the air pressure in kPa).

We can declare such conditions using [`Atmosphere`](@ref) such as:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
```

The [`Atmosphere`](@ref) also computes other variables based on the provided conditions, such as the vapor pressure deficit (VPD) or the air density (ρ). You can also provide those variables as inputs if necessary. For example if you need another way of computing the VPD, you can provide it as follows:

```@example usepkg
Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65, VPD = 0.82)
```

To access the values of the variables in after instantiation, we can use the dot syntax. For example if we need the vapor pressure at saturation, we would do as follows:

```@example usepkg
meteo.eₛ
```

See the documentation of the function if you need more information about the variables: [`Atmosphere`](@ref).

If you want to simulate several time-steps with varying conditions, you can do so by using [`Weather`](@ref) instead of [`Atmosphere`](@ref).

[`Weather`](@ref) is just an array of [`Atmosphere`](@ref) along with some optional metadata. For example for three time-steps, we can declare it like so:

```@example usepkg
w = Weather(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ],
    (site = "Montpellier",
    other_info = "another crucial metadata")
)
```

As you see the first argument is an array of [`Atmosphere`](@ref), and the second is a named tuple of optional metadata such as the site or whatever you think is important.

A [`Weather`](@ref) can also be declared from a DataFrame, provided each row is an observation from a time-step, and each column is a variable needed for [`Atmosphere`](@ref) (see the help of [`Atmosphere`](@ref) for more details on the possible variables and their units).

Here's an example of using a DataFrame as input:

```@example usepkg
using CSV, DataFrames
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","meteo.csv")
df = CSV.read(file, DataFrame; header=5, datarow = 6)
# Select and rename the variables:
select!(df, :date, :VPD, :temperature => :T, :relativeHumidity => :Rh, :wind => :Wind, :atmosphereCO2_ppm => :Cₐ)
df[!,:duration] .= 1800 # Add the time-step duration, 30min

# Make the weather, and add some metadata:
Weather(df, (site = "Aquiares", file = file))
```

One can also directly import the Weather from an Archimed-formatted meteorology file (a csv file optionally enriched with some metadata). In this case, the user can rename and transform the variables from the file to match the names and units needed in PlantBiophysics using a [`DataFrame.jl`](https://dataframes.juliadata.org/stable/)-alike syntax:

```@example usepkg
using Dates

meteo = read_weather(
    joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","meteo.csv"),
    :temperature => :T,
    :relativeHumidity => (x -> x ./100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)
```
