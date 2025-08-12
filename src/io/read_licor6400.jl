"""
    read_licor6400(file; abs=0.85, column_names_start=nothing, data_start=nothing, kwargs...)

Import Licor6400 data (such as Medlyn 2001 data) with the units and names corresponding to the ones used in PlantBiophysics.jl.

# Arguments

- `file`: a string or a vector of strings containing the path to the file(s) to read.
- `abs=0.85`: the absorptance of the leaf. Default is 0.85 (von Caemmerer et al., 2009).
- `column_names_start`: the row number to start reading column names from. If not provided, it is
  auto-detected from the `\$STARTOFDATA\$` marker (set to the line after the marker). Falls back to 3 if not found.
- `data_start`: the row number to start reading data from. If not provided, it is auto-detected from
  the `\$STARTOFDATA\$` marker (set to two lines after the marker), or defaults to `column_names_start + 1`.
- `kwargs...`: additional keyword arguments to pass to the CSV reader (*e.g.*, `decimal=','`).
"""
function read_licor6400(file; abs=0.85, column_names_start=nothing, data_start=nothing, kwargs...)
    # Compute defaults from file content when not provided
    if column_names_start === nothing && data_start === nothing
        # detect once (from first file if a vector is provided)
        firstfile = file isa AbstractVector{<:AbstractString} ? first(file) : file
        detected_header = nothing
        for (i, line) in enumerate(eachline(firstfile))
            if occursin(raw"$STARTOFDATA$", line)
                detected_header = i + 1
                break
            end
        end
        column_names_start = something(detected_header, 3)
        data_start = column_names_start + 1
    elseif column_names_start === nothing
        # user provided data_start; infer header as previous line
        data_start isa Integer || error("data_start must be an integer if provided")
        column_names_start = data_start - 1
    elseif data_start === nothing
        # user provided header; infer data start as next line
        column_names_start isa Integer || error("column_names_start must be an integer if provided")
        data_start = column_names_start + 1
    end

    # Read using the resolved indices
    df = read_file(file; column_names_start=column_names_start, data_start=data_start, kwargs...)

    if hasproperty(df, :Ttop)
        rename!(df, :Ttop => :Tmin)
    end

    #df[!,:Comment] = locf(df[!,:Comment])
    dropmissing!(df, :Press)
    hasproperty(df, :Qflag) && (df = df[df.Qflag.==1, :]) # Keep only the rows with Qflag == 1

    # Renaming variables to fit the standard in the package:
    select!(
        df,
        :HHMMSS => :Time,
        :Cond => :Gₛ, :CO2S => :Cₐ, :Tair => :T, :Press => :P, :RH_S => (x -> x ./ 100) => :Rh,
        :PARi => (x -> x .* abs) => :aPPFD, :Ci => :Cᵢ, :Tleaf => :Tₗ, :Photo => :A,
        :VpdL => :Dₗ, :BLCond => :Gbv, :
    )

    # Recomputing the variables to match the units used in the package:
    transform!(
        df,
        [:T, :Rh] => ((T, Rh) -> PlantMeteo.vpd.(Rh, T)) => :VPD,
        :Gₛ => (x -> gsw_to_gsc.(x)) => :Gₛ,
    )

    # select!(df, Not([:Cond,])) # Remove the Qflag column as it is not needed anymore
    return df
end
