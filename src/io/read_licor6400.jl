"""
    read_licor6400file)

Import Licor6400 data (such as Medlyn 2001 data).

"""
function read_licor6400(file)
    df = CSV.read(file, DataFrame, header = 1, skipto = 3)

    if hasproperty(df, :Ttop)
        rename!(df, :Ttop => :Tmin)
    end

    #df[!,:Comment] = locf(df[!,:Comment])
    dropmissing!(df, :Press)
    df = df[df.Qflag.==1,:]

    # Renaming variables to fit the standard in the package:
    rename!(
        df,
        :Cond => :Gₛ, :CO2S => :Cₐ, :Tair => :T, :Press => :P, :RH_S => :Rh,
        :PARi => :PPFD, :Ci => :Cᵢ, :Tleaf => :Tₗ,
        :VpdL => :Dₗ, :Photo => :A, :BLCond => :Gbv,
    )

    # Recomputing the variables to fit the units used in the package:
    df[!,:Rh] = df[!,:Rh] ./ 100.0
    transform!(
		df, 
		[:T,:Rh] => ((x,y) -> e_sat.(x) .- vapor_pressure.(x, y)) => :VPD,
		:Gₛ => (x -> gsw_to_gsc.(x)) => :Gₛ,
		[:A,:Cₐ,:Dₗ] => ((x,y,z) -> x ./ (y .* sqrt.(z))) => :AVPD,
	)
<<<<<<< HEAD
=======
    
>>>>>>> a5fa593a928c75d19296a6428bf4765477dfa28e

    return df
end
