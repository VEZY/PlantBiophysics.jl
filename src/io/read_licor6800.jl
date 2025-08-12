"""
    read_licor6800(file; column_names_start=65, data_start=column_names_start + 2, kwargs...)

Import Licor6800 data from the excel file with the units and names corresponding to the ones used in PlantBiophysics.jl.

# Arguments

- `file`: a string or a vector of strings containing the path to the file(s) to read.
- `column_names_start=65`: the row number to start reading column names from. Default is 65.
- `data_start=column_names_start+2`: the row number to start reading data from. Default is 67 (`column_names_start+2`).
- `kwargs...`: additional keyword arguments to pass to the CSV reader (*e.g.*, `decimal=','`).

The reference for the variables are found on the Licor 6800 website: See reference here: https://www.licor.com/support/LI-6800/topics/symbols.html
"""
function read_licor6800(file; column_names_start=65, data_start=column_names_start + 2, kwargs...)
    error_on_xlsx(file)

    if typeof(file) <: Vector{T} where {T<:AbstractString}
        df = CSV.read(file, DataFrame; header=column_names_start, skipto=data_start, source=:source, kwargs...)
    else
        df = CSV.read(file, DataFrame; header=column_names_start, skipto=data_start, kwargs...)
    end

    # Standard transformations for Licor 6800
    rename!(
        df,
        :Ci => :Cᵢ, :Tleaf => :Tₗ, :Qabs => :aPPFD, :VPDleaf => :Dₗ, :Pa => :P,
        :gsw => :Gₛ, :Ca => :Cₐ, :Tair => :T, :RHcham => :Rh, # A is already in the right format
    )

    # Recomputing the variables to match the units used in the package:
    df[!, :Rh] = df[!, :Rh] ./ 100.0
    transform!(
        df,
        [:T, :Rh] => ((T, Rh) -> PlantMeteo.vpd.(Rh, T)) => :VPD,
        :Gₛ => (x -> gsw_to_gsc.(x)) => :Gₛ,
    )
    return df
end
