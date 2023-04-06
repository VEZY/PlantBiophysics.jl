"""
    fit(
        ::Type{Fvcb}, df; 
        Tᵣ = nothing, 
        VcMaxRef = 0.0, JMaxRef = 0.0, RdRef = 0.0, TPURef = 0.0, 
        VcMaxRef_bound=[0.0, Inf], JMaxRef_bound=[0.0, Inf], RdRef_bound=[0.0, Inf], TPURef_bound=[0.0, Inf],
        verbose = true
    )

Optimize the parameters of the [`Fvcb`](@ref) model. Also works for [`FvcbIter`](@ref).

# Arguments

- df: a DataFrame with columns A, aPPFD, Tₗ and Cᵢ, where each row is an observation. The column
names should match exactly
- Tᵣ: reference temperature for the optimized parameter values. If not provided, use the average Tₗ.
- VcMaxRef, JMaxRef, RdRef, TPURef: initialisation values for the parameter optimisation
- VcMaxRef_bound, JMaxRef_bound, RdRef_bound, TPURef_bound: boundary values for the parameter optimisation
- verbose: if true, print the optimisation results

Note that boundary values are set to [0.0, Inf] by default. You should adapt them to your use case. Note that no 
boundary can be set using [-Inf, Inf].

# Examples

```julia
using PlantBiophysics, PlantMeteo, Plots, DataFrames

file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P1F20129.csv")
df = read_walz(file)
# Removing the Rh and light curves for the fitting because temperature varies
filter!(x -> x.curve != "Rh Curve" && x.curve != "ligth Curve", df)

# Fit the parameter values:
VcMaxRef, JMaxRef, RdRef, TPURef = fit(Fvcb, df; Tᵣ = 25.0)
# Note that Tᵣ was set to 25 °C in our response curve. You should adapt its value to what you
# had during the response curves

# Checking the results:
filter!(x -> x.curve == "CO2 Curve", df)

# Sort the DataFrame by :Cᵢ to get ordered data point
sort!(df, :Cᵢ)

# Re-simulating A using the newly fitted parameters:
leaf =
    ModelList(
        photosynthesis = FvcbRaw(VcMaxRef = VcMaxRef, JMaxRef = JMaxRef, RdRef = RdRef, TPURef = TPURef),
        status = (Tₗ = df.Tₗ, aPPFD = df.aPPFD, Cᵢ = df.Cᵢ)
    )
run!(leaf)
df_sim = DataFrame(leaf)

# Visualising the results:
ACi_struct = PlantBiophysics.ACi(VcMaxRef, JMaxRef, RdRef, df.A, df_sim.A, df[:,:Cᵢ], df_sim.Cᵢ)
plot(ACi_struct,leg=:bottomright)

# Note that we can also simulate the results using the full photosynthesis model too (Fvcb):
# Adding the windspeed to simulate the boundary-layer conductance (we put a high value):
df[!, :Wind] .= 10.0

leaf = ModelList(
        photosynthesis = Fvcb(VcMaxRef = VcMaxRef, JMaxRef = JMaxRef, RdRef = RdRef, Tᵣ = 25.0, TPURef = TPURef),
        # stomatal_conductance = ConstantGs(0.0, df[i,:Gₛ]),
        stomatal_conductance = Medlyn(0.03, 12.),
        status = (Tₗ = df.Tₗ, aPPFD = df.aPPFD, Cₛ = df.Cₐ, Dₗ = 0.1)
    )

w = Weather(select(df, :T, :P, :Rh, :Cₐ, :T => (x -> 10) => :Wind))
run!(leaf, w)
df_sim2 = DataFrame(leaf)

# And finally we plot the results:
ACi_struct_full = PlantBiophysics.ACi(VcMaxRef, JMaxRef, RdRef, df.A, df_sim2.A, df[:,:Cᵢ], df_sim2.Cᵢ)
plot(ACi_struct_full,leg=:bottomright)
# Note that the results differ a bit because there are more variables that are re-simulated (e.g. Cᵢ)
```
"""
function PlantSimEngine.fit(
    ::T, df;
    Tᵣ=nothing,
    VcMaxRef=0.0, JMaxRef=0.0, RdRef=0.0, TPURef=0.0,
    VcMaxRef_bound=[0.0, Inf], JMaxRef_bound=[0.0, Inf], RdRef_bound=[0.0, Inf], TPURef_bound=[0.0, Inf],
    verbose=false
) where {T<:Union{Type{Fvcb},Type{FvcbIter},Type{FvcbRaw}}}

    if Tᵣ === nothing
        Tᵣ = Statistics.mean(df.Tₗ)
    end

    function model(x, p)
        leaf =
            ModelList(
                photosynthesis=FvcbRaw(Tᵣ=Tᵣ, VcMaxRef=p[1], JMaxRef=p[2], RdRef=p[3], TPURef=p[4]),
                status=(Tₗ=x[:, 1], aPPFD=x[:, 2], Cᵢ=x[:, 3])
            )
        PlantSimEngine.run!(leaf)
        DataFrame(leaf).A
    end

    # Fitting the A-Cᵢ curve using LsqFit.jl
    # fits = curve_fit(model, df.Cᵢ[ind], df.A[ind], [VcMaxRef, JMaxRef, RdRef, TPURef])
    fits = curve_fit(
        model,
        Array(select(df, :Tₗ, :aPPFD, :Cᵢ)),
        df.A,
        [VcMaxRef, JMaxRef, RdRef, TPURef],
        lower=[VcMaxRef_bound[1], JMaxRef_bound[1], RdRef_bound[1], TPURef_bound[1]],
        upper=[VcMaxRef_bound[2], JMaxRef_bound[2], RdRef_bound[2], TPURef_bound[2]],
        show_trace=verbose)

    return (VcMaxRef=fits.param[1], JMaxRef=fits.param[2], RdRef=fits.param[3], TPURef=fits.param[4], Tᵣ=Tᵣ)
end

# Plot recipes for making A/Ci curves:
mutable struct ACi
    VcMaxRef
    JMaxRef
    RdRef
    A_meas
    A_sim
    Cᵢ_meas
    Cᵢ_sim
end

ACi(VcMaxRef, JMaxRef, RdRef, A_meas, A_sim, Cᵢ_meas) = ACi(VcMaxRef, JMaxRef, RdRef, A_meas, A_sim, Cᵢ_meas, copy(Cᵢ_meas))

@recipe function f(h::ACi)
    x = h.Cᵢ_meas
    x2 = h.Cᵢ_sim
    y = h.A_meas
    y2 = h.A_sim
    # Main plot (measurement):
    xguide --> "Cᵢ (ppm)"
    yguide --> "A (μmol m⁻² s⁻¹)"

    EF_ = round(PlantSimEngine.EF(y, y2), digits=3)
    dr_ = round(PlantSimEngine.dr(y, y2), digits=3)
    RMSE_ = round(PlantSimEngine.RMSE(y, y2), digits=3)

    @series begin
        seriestype := :scatter
        label := "Measured"
        x, y
    end

    @series begin
        label := "Simulated (EF:$EF_,dr:$dr_,RMSE:$RMSE_)"
        seriestype := :line
        x2, y2
    end
end
