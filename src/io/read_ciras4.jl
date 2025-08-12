"""
    read_ciras4(file; abs=0.85, column_names_start=1, data_start=column_names_start + 1, kwargs...)

Read PPSystem CIRAS-4 data and return a DataFrame.

# Arguments

- `file`: The path to the CIRAS-4 data file, or vector of file paths.
- `abs`: The absorptance of the leaf. Default is 0.85 (von Caemmerer et al., 2009).
- `column_names_start`: The row number where column names start (default is 1).
- `data_start`: The row number where data starts (default is column_names_start + 1).
- `kwargs`: Additional keyword arguments to pass to the CSV reader (*e.g.*, `decimal=','`).
"""
function read_ciras4(file; abs=0.85, column_names_start=1, data_start=column_names_start + 1, kwargs...)
    df = read_file(file; column_names_start=column_names_start, data_start=data_start, kwargs...)
    rename!(strip, df)

    # Renaming variables to fit the standard in the package:
    select!(
        df,
        "DateTime" => (x -> Dates.DateTime.(x, "dd/mm/yyyy HH:MM:SS")) => "DateTime",
        "PARi" => (x -> x .* abs) => "aPPFD", "Tcuv" => "T", "Tleaf" => "Tₗ", "A",
        "VPD" => "Dₗ", "Patm" => "P", "Aleaf" => "Area",
        "RH" => (x -> x ./ 100.0) => "Rh",
        "Ci" => "Cᵢ", "gs" => (x -> gsw_to_gsc.(x)) => "Gₛ",
    )

    # Recomputing the variables to fit the units used in the package:
    df[!, :VPD] = PlantMeteo.vpd.(df.Rh, df.T)
    return df
end