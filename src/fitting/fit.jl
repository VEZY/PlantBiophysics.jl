"""

# Examples

```julia
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P1F20129.csv")
df = read_walz(file)
# Removing the Rh curve for the fitting because temperature varies
filter!(x -> x.curve != "Rh Curve", df)
fit(Fvcb, df; Tᵣ = 25.0, VcMaxRef = 200.0, JMaxRef = 250.0, RdRef = 0.6)
# Note that Tᵣ was set to 25 °C in our response curve. You should adapt its value to what you
# had during the response curves
```
"""
function fit(::Fvcb, df; Tᵣ = 25.0, VcMaxRef = 200.0, JMaxRef = 250.0, RdRef = 0.6)

    function model(df, p)

        df[!,:Wind] .= 10.0

        w = Weather(select(df, :T, :P, :Rh, :Wind, :Cₐ))

        leaves = Vector{LeafModels}(undef, nrow(df))
        for i in 1:nrow(df)
            leaves[i] =
                LeafModels(
                    photosynthesis = Fvcb(Tᵣ = Tᵣ, VcMaxRef = p[1], JMaxRef = p[2], RdRef = p[3]),
                    stomatal_conductance = ConstantGs(0.0, df[i,:gs]),
                    Tₗ = df[i,:T], PPFD = df[i,:PPFD], Cₛ = df[i,:Cₐ])
            # NB: we need  to initalise Tₗ, PPFD and Cₛ
        end

        assimilation!(leaves, w)

        return DataFrame(w).A
    end

    p0 = [VcMaxRef, JMaxRef, RdRef]
    curve_fit(model, df, df.A, p0)
end
