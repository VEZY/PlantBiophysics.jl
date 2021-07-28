"""
    read_walz(file)

Import a Walz GFS-3000 output file.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P1F20129.csv")
read_walz(file)
```
"""
function read_walz(file)
    df = CSV.read(file, DataFrame, header = 1, datarow = 3)

    if hasproperty(df, :Ttop)
        rename!(df, :Ttop => :Tmin)
    end

    df[!,:Comment] = locf(df[!,:Comment])
    dropmissing!(df, :VPD)

    # Renaming variables to fit the standard in the package:
    rename!(
        df,
        :GH2O => :gs, :ca => :Cₐ, :Tcuv => :T, :Pamb => :P, :rh => :Rh,
        :PARtop => :PPFD, :ci => :Cᵢ, :Comment => :curve
    )

    # Recomputing the variables to fit the units used in the package:
    df[!,:VPD] = round.(df[:,:VPD] .* df[:,:P] ./ 1000.0, digits = 3)
    df[!,:gs] = round.(gsw_to_gsc.(df[:,:gs]) ./ 1000.0, digits = 5)
    df[!,:AVPD] = df[:,:A] ./ (df[:,:Cₐ] .* sqrt.(df[:,:VPD]))
    df[!,:Rh] = df[!,:Rh] ./ 100.0

    return df
end
