"""

# Examples

```julia
using Plots

file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P5F70323.csv")
df = read_walz(file)
# Removing the Rh curve for the fitting because temperature varies
filter!(x -> x.curve != "Rh Curve", df)
VcMaxRef, JMaxRef, RdRef = fit(Fvcb, df; Tᵣ = 25.0, VcMaxRef = 200.0, JMaxRef = 250.0, RdRef = 0.6)
# Note that Tᵣ was set to 25 °C in our response curve. You should adapt its value to what you
# had during the response curves

# Checking the results:
filter!(x -> x.curve == "CO2 Curve", df)
df[!, :Wind] .= 10.0

# Sort the DataFrame by :Cᵢ to get ordered data point
sort!(df, :Cᵢ)

A = Vector{Float64}(undef, size(df, 1))

for i in 1:size(df,1)
    leaf =
        LeafModels(
            photosynthesis = Fvcb(VcMaxRef = VcMaxRef, JMaxRef = JMaxRef, RdRef = RdRef, Tᵣ = 25.0),
            stomatal_conductance = ConstantGs(0.0, df[i,:gs]),
            Tₗ = df[i,:T], PPFD = df[i,:PPFD], Cₛ = df[i,:Cₐ])

    meteo = Atmosphere(T = df[i,:T], Wind = 10.0, P = df[i,:P], Rh = df[i,:Rh], Cₐ = df[i,:Cₐ])
    photosynthesis!(leaf, meteo)
    A[i] = leaf.status.A
end

scatter(df[:,:Cᵢ], df[:,:A], label = "Measured", xlabel = "Cᵢ", ylabel = "A")
plot!(df[:,:Cᵢ], A, label = "Simulated", xlabel = "Cᵢ", ylabel = "A")
```
"""
function fit(::Type{Fvcb}, df; Tᵣ = 25.0, VcMaxRef = 200.0, JMaxRef = 250.0, RdRef = 0.6)

    df_in = copy(df)

    if !hasproperty(df_in, :Wind)
    df_in[!, :Wind] .= 10.0
    end

    function model(x, p)

        A = Vector{Float64}(undef, size(x, 1))

        for i in 1:size(x, 1)
            meteo = Atmosphere(T = x[i,1], Wind = x[i,7], P = x[i,5], Rh = x[i,6], Cₐ = x[i,4])

            leaf =
                LeafModels(
                    photosynthesis = Fvcb(Tᵣ = Tᵣ, VcMaxRef = p[1], JMaxRef = p[2], RdRef = p[3]),
                    stomatal_conductance = ConstantGs(0.0, x[i,3]),
                    Tₗ = x[i,1], PPFD = x[i,2], Cₛ = x[i,4])
            # NB: we need  to initalise Tₗ, PPFD and Cₛ

            photosynthesis!(leaf, meteo)
            A[i] = leaf.status.A
    end


    return A
    end

    A = df_in[:, :A]
    select!(df_in, :T, :PPFD, :gs, :Cₐ, :P, :Rh, :Wind)

    p0 = [VcMaxRef, JMaxRef, RdRef]
    array_x = Array(df_in)

    res = curve_fit(model, array_x, A, p0)

    (VcMaxRef = res.param[1], JMaxRef = res.param[2], RdRef = res.param[3])
end
