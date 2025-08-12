"""
    read_walz(file; abs=0.85)

Import a Walz GFS-3000 output file, perform variables conversion and rename
according to package conventions.

# Arguments

- `file`: a string or a vector of strings containing the path to the file(s) to
  read.
- `abs=0.85`: the absorptance of the leaf. Default is 0.85 (von Caemmerer et al., 2009).

# Returns

A DataFrame containing the data read and transformed from the file(s). The units are the same than in the Walz output file, 
except for:

- Dₗ: kPa
- Rh: fraction (0-1)
- VPD: kPa
- Gₛ: mol[CO₂] m⁻² s⁻¹

# Examples

Reading one file:

```julia
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P1F20129.csv")
read_walz(file)
```

We can also read multiple files at once:

```julia
files = readdir(joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data"), join = true)
df = read_walz(files)
```

In this case, the source of the data is added as the `source` columns into the DataFrame:

```julia
df.source
```
"""
function read_walz(file; abs=0.85)
    error_on_xlsx(file)

    if typeof(file) <: Vector{T} where {T<:AbstractString}
        df = CSV.read(file, DataFrame, header=1, skipto=3, source=:source)
    else
        df = CSV.read(file, DataFrame, header=1, skipto=3)
    end

    if hasproperty(df, :Ttop)
        rename!(df, :Ttop => :Tmin)
    end

    locf!(df[!, :Comment])

    dropmissing!(df, :VPD)

    # Renaming variables to fit the standard in the package:
    transform!(
        df,
        :GH2O => :Gₛ, :ca => :Cₐ, :Tcuv => :T, :Pamb => :P, :rh => :Rh,
        :PARtop => (x -> x .* abs) => :aPPFD, :ci => :Cᵢ, :Comment => :curve, :Tleaf => :Tₗ,
        :VPD => :Dₗ
    )

    # Recomputing the variables to fit the units used in the package:

    df[!, :Dₗ] = df.Dₗ .* df.P ./ 1000.0
    df[!, :Rh] = df[!, :Rh] ./ 100.0
    df[!, :VPD] = PlantMeteo.vpd.(df.Rh, df.T)
    df[!, :Gₛ] = round.(gsw_to_gsc.(df[:, :Gₛ]) ./ 1000.0, digits=5)

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
