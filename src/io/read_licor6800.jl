"""
    read_licor6800(file; abs=0.85)

Import Licor6800 data from the excel file with the units and names corresponding to the ones used in PlantBiophysics.jl.

# Arguments

- `file`: a string or a vector of strings containing the path to the file(s) to read.
- `abs=0.85`: the absorptance of the leaf. Default is 0.85 (von Caemmerer et al., 2009).

The reference for the variables are found on the Licor 6800 website: See reference here: https://www.licor.com/support/LI-6800/topics/symbols.html
"""
function read_licor6800(file; abs=0.85)
    if typeof(file) <: Vector{T} where {T<:AbstractString}
        df = CSV.read(file, DataFrame, header=65, skipto=67, source=:source)
    else
        df = CSV.read(file, DataFrame, header=65, skipto=67)
    end

    # Renaming variables to fit the standard in the package:
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
