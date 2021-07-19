using Base:Symbol
"""
    read_meteo(file)

Read a meteo file. The meteo file is a CSV with a commented YAML header for the metadata.

# Arguments

- `file::String`: path to a meteo file

# Examples

```julia
using Dates

file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","meteo.csv")
vars_dict = Dict(:temperature => :T, :relativeHumidity => :Rh, :relativeHumidity => :Rh, :wind => :Wind, :atmosphereCO2_ppm => :Cₐ)

meteo = read_meteo(file, vars_dict, date_format = DateFormat("yyyy/mm/dd"))
```
"""
function read_meteo(file)
    data, metadata = read_meteo(file, DataFrame)
    Weather(data, metadata)
end

function read_meteo(
    file,
    vars_dict;
    date_format = DateFormat("yyyy-mm-ddTHH:MM:SS.s"),
    hour_format = DateFormat("HH:MM:SS")
    )

    data, metadata = read_meteo(file, DataFrame)

    # Clean-up the variable names:
    rename!(data, vars_dict...)

    # If there's a "use" field in the YAML, parse it and rename it:
    if haskey(metadata, "use")
        splitted_use = split(metadata["use"], r"[,\s]")
        metadata["use"] = Symbol.(splitted_use[findall(x -> length(x) > 0, splitted_use)])
        replace!(metadata["use"], vars_dict...)
    end
    # NB: the "use" field is not used in PlantBiophysics, but it is still correctly parsed.

    if hasproperty(data, :date) && typeof(data.date[1]) != DateTime
        # There's a "date" column but it is not a DateTime
        # Trying to parse it with the user-defined format:
        try
            data.date = Dates.DateTime.(data.date, date_format)
        catch
            error(
                "The values in the `date` column cannot be parsed.",
                " Please check the format of the dates or provide the format as argument."
            )
        end

        if typeof(data.date[1]) == Dates.Date && hasproperty(data, :hour_start)
            # The `date` column is of Date type, we have to add the Time if there's a column named
            # `hour_start`:
            if typeof(data.hour_start[1]) != Dates.Time
                # There's a "hour_start" column but it is not of Time type
                # If it is a String, it did not parse at reading with CSV, so trying to use
                # the user-defined format:
                try
                    data.hour_start = Dates.Time.(data.hour_start, hour_format)
                catch
                    error(
                        "The values in the `hour_start` column cannot be parsed.",
                        " Please check the format of the hours or provide the format as argument."
                    )
                end
            end
            # Adding the Time to the Date to make a DateTime:
            data.date = data.date .+ data.hour_start
        end
    end

    # `duration` is not in the df but there is an `hour_end` column:
    if hasproperty(data, :hour_end) && !hasproperty(data, :duration)
        if typeof(data.hour_end[1]) != Dates.Time
            # There's a `hour_end` column but it is not of Time type
            # If it is a String, it did not parse at reading with CSV, so trying to use
            # the user-defined format:
            if typeof(data.hour_end[1]) != String
                try
                    data.hour_end = Dates.Time.(data.hour_end, hour_format)
                catch
                    error(
                            "The values in the `hour_end` column cannot be parsed.",
                            " Please check the format of the hours or provide the format as argument."
                        )
                end
            end

            # If it is of Time type, transform it into a DateTime:
            if typeof(data.hour_end[1]) == dates.DateTime
                data.hour_end = Dates.Time(data.hour_end)
            end
        end

        data.duration = Minute.(data.hour_end .- data.hour_start)
    end

    cols = fieldnames(Atmosphere)
    select!(data, names(data, x -> Symbol(x) in cols))

    Weather(data, metadata)
end

function read_meteo(file, ::Type{DataFrame})
    yaml_data = open(file, "r") do io
        yaml_data = ""
        is_yaml = true
        while is_yaml
            line = readline(io, keep = true)
            if line[1:2] == "#'"
                yaml_data *= lstrip(line[3:end])
            else
                is_yaml = false
            end
        end
        return yaml_data
    end

    metadata = YAML.load(yaml_data)

    met_data = CSV.read(file, DataFrame; comment = "#")

    (data = met_data, metadata = metadata)
end
