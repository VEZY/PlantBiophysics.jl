"""
    Weather(D <: AbstractArray{<:AbstractAtmosphere}[, S])
    Weather(df::DataFrame[, mt])

Defines the weather, *i.e.* the local conditions of the Atmosphere for one or more time-steps.
Each time-step is described using the [`Atmosphere`](@ref) structure.

The simplest way to instantiate a `Weather` is to use a `DataFrame` as input.

The `DataFrame` should be formated such as each row is an observation for a given time-step
and each column is a variable. The column names should match exactly the field names of the
[`Atmosphere`](@ref) structure, `i.e.`:

```@example
fieldnames(Atmosphere)
```

## See also

- the [`Atmosphere`](@ref) structure
- the [`read_weather`](@ref) function to read Archimed-formatted meteorology data.

## Examples

```julia
# Example of weather data defined by hand (cumbersome):
w = Weather(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ],
    (
        site = "Test site",
        important_metadata = "this is important and will be attached to our weather data"
    )
)

# Example using a DataFrame, that you would usually import from a file:
using CSV, DataFrames
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","meteo.csv")
df = CSV.read(file, DataFrame; header=5, datarow = 6)
# Select and rename the variables:
select!(df, :date, :VPD, :temperature => :T, :relativeHumidity => :Rh, :wind => :Wind, :atmosphereCO2_ppm => :Cₐ)
df[!,:duration] .= 1800 # Add the time-step duration, 30min

# Make the weather, and add some metadata:
Weather(df, (site = "Aquiares", file = file))
```
"""
struct Weather{D<:AbstractArray{<:AbstractAtmosphere},S<:Status}
    data::D
    metadata::S
end

function Weather(df::T) where {T<:AbstractArray{<:AbstractAtmosphere}}
    Weather(df, Status())
end

function Weather(df::T, mt::S) where {T<:AbstractArray{<:AbstractAtmosphere},S<:NamedTuple}
    Weather(df, Status(; mt...))
end

function Weather(df::DataFrame, mt::S) where {S<:Status}
    Weather([Atmosphere(; i...) for i in eachrow(df)], mt)
end

function Weather(df::DataFrame, mt::S) where {S<:NamedTuple}
    mt = Status(; mt...)
    Weather([Atmosphere(; i...) for i in eachrow(df)], mt)
end

function Weather(df::DataFrame, dict::S) where {S<:AbstractDict}
    # There must be a better way for transforming a Dict into a Status...
    Weather(df, Status(; NamedTuple{Tuple(Symbol.(keys(dict)))}(values(dict))...))
end

function Weather(df::DataFrame)
    Weather(df, Status())
end

function Base.show(io::IO, n::Weather)
    printstyled(io, "Weather data.\n", bold=true, color=:green)
    printstyled(io, "Metadata: `$(NamedTuple(n.metadata))`.\n", color=:cyan)
    printstyled(io, "Data:\n", color=:green)
    # :normal, :default, :bold, :black, :blink, :blue, :cyan, :green, :hidden, :light_black, :light_blue, :light_cyan, :light_green, :light_magenta, :light_red, :light_yellow, :magenta, :nothing, :red,
    #   :reverse, :underline, :white, or :yellow
    print(io, DataFrame(n))
    return nothing
end

Base.getindex(w::Weather, i::Integer) = w.data[i]
Base.getindex(w::Weather, s::Symbol) = [getproperty(i, s) for i in w.data]
Base.length(w::Weather) = length(w.data)

"""
    DataFrame(data::Weather)

Transform a Weather type into a DataFrame.

See also [`Weather`](@ref) to make the reverse.
"""
function DataFrame(data::Weather)
    return DataFrame(data.data)
end
