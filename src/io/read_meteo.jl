using Base:Symbol
"""
    read_meteo(file)

Read a meteo file. The meteo file is a CSV with a commented YAML header for the metadata.

# Arguments

- `file::String`: path to a meteo file

# Examples

```julia
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","meteo.csv")
meteo = read_meteo(file)
```
"""
function read_meteo(file)
    data, metadata = read_meteo(file, DataFrame)
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
