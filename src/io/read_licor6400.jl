"""
    read_licor6400(file; abs=0.85)

Import Licor6400 data (such as Medlyn 2001 data) with the units and names corresponding to the ones used in PlantBiophysics.jl.

# Arguments

- `file`: a string or a vector of strings containing the path to the file(s) to read.
- `abs=0.85`: the absorptance of the leaf. Default is 0.85 (von Caemmerer et al., 2009).
- `column_names_start=3`: the row number to start reading column names from. Default is 3.
- `data_start=column_names_start+1`: the row number to start reading data from. Default is 4 (`column_names_start+1`).
- `kwargs...`: additional keyword arguments to pass to the CSV reader (*e.g.*, `delim=','`).
"""
function read_licor6400(file; abs=0.85, column_names_start=3, data_start=column_names_start + 1, kwargs...)

    error_on_xlsx(file)

    if typeof(file) <: Vector{T} where {T<:AbstractString}
        df = CSV.read(file, DataFrame; header=column_names_start, skipto=data_start, source=:source, kwargs...)
    else
        df = CSV.read(file, DataFrame; header=column_names_start, skipto=data_start, kwargs...)
    end

    if hasproperty(df, :Ttop)
        rename!(df, :Ttop => :Tmin)
    end

    #df[!,:Comment] = locf(df[!,:Comment])
    dropmissing!(df, :Press)
    hasproperty(df, :Qflag) && (df = df[df.Qflag.==1, :]) # Keep only the rows with Qflag == 1

    # Renaming variables to fit the standard in the package:
    transform!(
        df,
        :Cond => :Gₛ, :CO2S => :Cₐ, :Tair => :T, :Press => :P, :RH_S => :Rh,
        :PARi => (x -> x .* abs) => :aPPFD, :Ci => :Cᵢ, :Tleaf => :Tₗ,
        :VpdL => :Dₗ, :Photo => :A, :BLCond => :Gbv,
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
