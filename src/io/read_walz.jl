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
    df = CSV.read(file, DataFrame, header=1, skipto=3)

    if hasproperty(df, :Ttop)
        rename!(df, :Ttop => :Tmin)
    end

    locf!(df[!, :Comment])

    dropmissing!(df, :VPD)

    # Renaming variables to fit the standard in the package:
    rename!(
        df,
        :GH2O => :Gₛ, :ca => :Cₐ, :Tcuv => :T, :Pamb => :P, :rh => :Rh,
        :PARtop => :PPFD, :ci => :Cᵢ, :Comment => :curve, :Tleaf => :Tₗ,
        :VPD => :Dₗ
    )

    # Recomputing the variables to fit the units used in the package:
    df[!, :VPD] = PlantMeteo.vpd(df.Rh, df.T)
    df[!, :Gₛ] = round.(gsw_to_gsc.(df[:, :Gₛ]) ./ 1000.0, digits=5)
    df[!, :AVPD] = df[:, :A] ./ (df[:, :Cₐ] .* sqrt.(df[:, :VPD]))
    df[!, :Rh] = df[!, :Rh] ./ 100.0

    return df
end


"""
    locf!(var)

Last observation carried forward (LOCF) iterates forwards `var` and fills
missing data with the last existing observation.

This function is heavily inspired (*i.e.* copied) by the function `locf` in the package
`Impute` (MIT licence). See
[here](https://github.com/invenia/Impute.jl/blob/9230661ae5f3dc828fea58b32970c874574cb654/src/imputors/locf.jl#LL44-L64)
for more details.
"""
function locf!(var)
    @assert !all(ismissing, var)
    start_idx = findfirst(!ismissing, var)
    for i in start_idx+1:lastindex(var)
        if ismissing(var[i])
            var[i] = var[i-1]
        else
            start_idx = i
        end
    end

    return var
end
