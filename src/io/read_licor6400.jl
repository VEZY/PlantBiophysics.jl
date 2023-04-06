"""
    read_licor6400(file)

Import Licor6400 data (such as Medlyn 2001 data) with the units and names corresponding to the ones used in PlantBiophysics.jl.

"""
function read_licor6400(file)
    df = CSV.read(file, DataFrame, header=1, skipto=3)

    if hasproperty(df, :Ttop)
        rename!(df, :Ttop => :Tmin)
    end

    #df[!,:Comment] = locf(df[!,:Comment])
    dropmissing!(df, :Press)
    df = df[df.Qflag.==1, :]

    # Renaming variables to fit the standard in the package:
    rename!(
        df,
        :Cond => :Gₛ, :CO2S => :Cₐ, :Tair => :T, :Press => :P, :RH_S => :Rh,
        :PARi => :aPPFD, :Ci => :Cᵢ, :Tleaf => :Tₗ,
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
