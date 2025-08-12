"""
    read_licor6800(file; column_names_start=nothing, data_start=nothing, kwargs...)

Import Licor6800 data from CSV or text file with the units and names corresponding to the ones used in PlantBiophysics.jl.

# Arguments

- `file`: a string or a vector of strings containing the path to the file(s) to read.
- `column_names_start`: the row number to start reading column names from. If not provided, it is
  auto-detected as the first row that starts with `obs` (case-sensitive). Falls back to 14 if not found.
- `data_start`: the row number to start reading data from. If not provided, it is set to
  `column_names_start + 2` by default.
- `kwargs...`: additional keyword arguments to pass to the CSV reader (*e.g.*, `decimal=','`).

The reference for the variables are found on the Licor 6800 website: See reference here: https://www.licor.com/support/LI-6800/topics/symbols.html
"""
function read_licor6800(file; column_names_start=nothing, data_start=nothing, kwargs...)
    # --- auto-detect column and data rows if not provided ---
    if column_names_start === nothing && data_start === nothing
        firstfile = file isa AbstractVector{<:AbstractString} ? first(file) : file
        detected_header = nothing
        for (i, line) in enumerate(eachline(firstfile))
            s = strip(line)
            if startswith(s, "obs")
                detected_header = i
                break
            end
        end
        column_names_start = something(detected_header, 14)
        data_start = column_names_start + 2
    elseif column_names_start === nothing
        data_start isa Integer || error("data_start must be an integer if provided")
        column_names_start = data_start - 2
    elseif data_start === nothing
        column_names_start isa Integer || error("column_names_start must be an integer if provided")
        data_start = column_names_start + 2
    end

    df = read_file(file; column_names_start=column_names_start, data_start=data_start, kwargs...)

    # Standard transformations for Licor 6800
    select!(
        df,
        :date => (x -> Dates.DateTime.(x, "yyyymmdd HH:MM:SS")) => :DateTime,
        :Ci => :Cᵢ, :Tleaf => :Tₗ, :Qabs => :aPPFD, :VPDleaf => :Dₗ, :Pa => :P,
        :gsw => :Gₛ, :Ca => :Cₐ, :Tair => :T, :RHcham => :Rh, # A is already in the right format
        :
    )

    # Recomputing the variables to match the units used in the package:
    df[!, :Rh] = df[!, :Rh] ./ 100.0
    transform!(
        df,
        [:T, :Rh] => ((T, Rh) -> PlantMeteo.vpd.(Rh, T)) => :VPD,
        :Gₛ => (x -> gsw_to_gsc.(x)) => :Gₛ,
    )

    select!(df, Not([:time, :date, :hhmmss, :TIME, :Ci, :Ca, :Pa, :Tleaf, :Qabs, :VPDleaf, :gsw, :Tair, :RHcham]))
    return df
end
