"""
    read_licor6400file)

Import Licor6400 data (such as Medlyn 2001 data).

"""
function read_licor6400(file)
    df = CSV.read(file, DataFrame, header = 1, datarow = 3)

    if hasproperty(df, :Ttop)
        rename!(df, :Ttop => :Tmin)
    end

    #df[!,:Comment] = locf(df[!,:Comment])
    dropmissing!(df, :Press)
    df = df[df.Qflag.==1,:]

    # Renaming variables to fit the standard in the package:
    rename!(
        df,
        :Cond => :gs, :CO2S => :Cₐ, :Tair => :T, :Press => :P, :RH_S => :Rh,
        :PARi => :PPFD, :Ci => :Cᵢ, :Tleaf => :Tₗ,
        :VpdL => :Dₗ, :Photo => :A, :BLCond => :Gbv,
    )

    # Recomputing the variables to fit the units used in the package:
    df[!,:VPD] = df[!,:Dₗ]
    df[!,:gs] = round.(gsw_to_gsc.(df[:,:gs]), digits = 5)
    df[!,:AVPD] = df[:,:A] ./ (df[:,:Cₐ] .* sqrt.(df[:,:Dₗ]))
    df[!,:Rh] = df[!,:Rh] ./ 100.0

    return df
end