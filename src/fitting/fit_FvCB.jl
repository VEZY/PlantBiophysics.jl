"""
    Evaluation.fit(
        ::Type{Fvcb}, df; 
        Tᵣ = nothing, 
        VcMaxRef = 0.0, JMaxRef = 0.0, RdRef = 0.0, TPURef = 0.0, 
        VcMaxRef_bound=[0.0, Inf], JMaxRef_bound=[0.0, Inf], RdRef_bound=[0.0, Inf], TPURef_bound=[0.0, Inf],
        verbose = true,
        Eₐᵣ=46390.0, O₂=210.0, Eₐⱼ=29680.0, Hdⱼ=200000.0, Δₛⱼ=631.88, Eₐᵥ=58550.0, Hdᵥ=200000.0, Δₛᵥ=629.26, α=0.425, θ=0.7
    )

Optimize the parameters of the [`Fvcb`](@ref) model. Also works for [`FvcbIter`](@ref).

# Arguments

- df: a DataFrame with columns A, aPPFD, Tₗ and Cᵢ, where each row is an observation. The column
names should match exactly
- Tᵣ: reference temperature for the optimized parameter values. If not provided, use the average Tₗ.
- VcMaxRef, JMaxRef, RdRef, TPURef: initialisation values for the parameter optimisation
- VcMaxRef_bound, JMaxRef_bound, RdRef_bound, TPURef_bound: boundary values for the parameter optimisation
- verbose: if true, print the optimisation results
- Eₐᵣ, O₂, Eₐⱼ, Hdⱼ, Δₛⱼ, Eₐᵥ, Hdᵥ, Δₛᵥ, α, θ: parameters for the FvCB model

FvCB model parameters:

$FVCB_PARAMETERS

Note that boundary values are set to [0.0, Inf] by default. You should adapt them to your use case. Note that no 
boundary can be set using [-Inf, Inf].

# Examples

```julia
using PlantBiophysics, PlantSimEngine, PlantSimEngine.Evaluation, PlantMeteo, Plots, DataFrames

file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P1F20129.csv")
df = read_walz(file)
# Removing the Rh and light curves for the fitting because temperature varies
filter!(x -> x.curve != "Rh Curve" && x.curve != "ligth Curve", df)

# Fit the parameter values:
VcMaxRef, JMaxRef, RdRef, TPURef = Evaluation.fit(Fvcb, df; Tᵣ = 25.0)
# Note that Tᵣ was set to 25 °C in our response curve. You should adapt its value to what you
# had during the response curves

# Checking the results:
filter!(x -> x.curve == "CO2 Curve", df)

# Sort the DataFrame by :Cᵢ to get ordered data point
sort!(df, :Cᵢ)

# Re-simulating A using the newly fitted parameters:
A_sim = map(eachrow(df)) do row
    scene = leaf_scene(
        FvcbRaw(VcMaxRef = VcMaxRef, JMaxRef = JMaxRef, RdRef = RdRef, TPURef = TPURef);
        status = Status(Tₗ = row.Tₗ, aPPFD = row.aPPFD, Cᵢ = row.Cᵢ),
    )
    run!(scene)
    only(model_objects(scene; scale = :Leaf)).status.A
end

# Visualising the results:
ACi_struct = PlantBiophysics.ACi(VcMaxRef, JMaxRef, RdRef, df.A, A_sim, df[:,:Cᵢ])
plot(ACi_struct,leg=:bottomright)

# Note that we can also simulate the results using the full photosynthesis model too (Fvcb):
# Adding the windspeed to simulate the boundary-layer conductance (we put a high value):
df[!, :Wind] .= 10.0

A_sim2 = map(eachrow(df)) do row
    meteo = Atmosphere(T = row.T, P = row.P, Rh = row.Rh, Cₐ = row.Cₐ, Wind = 10.0)
    scene = leaf_scene(
        Fvcb(VcMaxRef = VcMaxRef, JMaxRef = JMaxRef, RdRef = RdRef, Tᵣ = 25.0, TPURef = TPURef),
        Medlyn(0.03, 12.0);
        status = Status(Tₗ = row.Tₗ, aPPFD = row.aPPFD, Cₛ = row.Cₐ, Dₗ = 0.1),
        environment = meteo,
    )
    run!(scene)
    only(model_objects(scene; scale = :Leaf)).status.A
end

# And finally we plot the results:
ACi_struct_full = PlantBiophysics.ACi(VcMaxRef, JMaxRef, RdRef, df.A, A_sim2, df[:,:Cᵢ])
plot(ACi_struct_full,leg=:bottomright)
# Note that the results differ a bit because there are more variables that are re-simulated (e.g. Cᵢ)
```
"""
function PlantSimEngine.Evaluation.fit(
    ::T, df;
    Tᵣ=nothing,
    VcMaxRef=0.0, JMaxRef=0.0, RdRef=0.0, TPURef=0.0,
    VcMaxRef_bound=[0.0, Inf], JMaxRef_bound=[0.0, Inf], RdRef_bound=[0.0, Inf], TPURef_bound=[0.0, Inf],
    verbose=false,
    Eₐᵣ=46390.0, O₂=210.0, Eₐⱼ=29680.0, Hdⱼ=200000.0, Δₛⱼ=631.88, Eₐᵥ=58550.0, Hdᵥ=200000.0, Δₛᵥ=629.26, α=0.425, θ=0.7
) where {T<:Union{Type{Fvcb},Type{FvcbIter},Type{FvcbRaw}}}

    if Tᵣ === nothing
        Tᵣ = Statistics.mean(df.Tₗ)
    end

    function model(x, p)
        A = convert(eltype(p), -9999.0) #We promote the model output to `ForwardDiff.Dual` when the call passes the parameters as this type during optimisation.
        photosynthesis = FvcbRaw(
            Tᵣ=Tᵣ,
            VcMaxRef=p[1],
            JMaxRef=p[2],
            RdRef=p[3],
            TPURef=p[4],
            Eₐᵣ=Eₐᵣ,
            O₂=O₂,
            Eₐⱼ=Eₐⱼ,
            Hdⱼ=Hdⱼ,
            Δₛⱼ=Δₛⱼ,
            Eₐᵥ=Eₐᵥ,
            Hdᵥ=Hdᵥ,
            Δₛᵥ=Δₛᵥ,
            α=α,
            θ=θ,
        )
        simulated = Vector{typeof(A)}(undef, size(x, 1))
        for i in axes(x, 1)
            leaf = leaf_scene(
                photosynthesis;
                status=Status(
                    Tₗ=x[i, 1],
                    aPPFD=x[i, 2],
                    Cᵢ=x[i, 3],
                    A=A,
                ),
            )
            PlantSimEngine.run!(leaf)
            simulated[i] = only(
                PlantSimEngine.model_objects(leaf; scale=:Leaf),
            ).status.A
        end
        return simulated
    end

    # Fitting the A-Cᵢ curve using LsqFit.jl
    # fits = LsqFit.curve_fit(model, df.Cᵢ[ind], df.A[ind], [VcMaxRef, JMaxRef, RdRef, TPURef])
    fits = LsqFit.curve_fit(
        model,
        Array(select(df, :Tₗ, :aPPFD, :Cᵢ)),
        df.A,
        [VcMaxRef, JMaxRef, RdRef, TPURef],
    )

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

    EF_ = round(PlantSimEngine.Evaluation.EF(y, y2), digits=3)
    dr_ = round(PlantSimEngine.Evaluation.dr(y, y2), digits=3)
    RMSE_ = round(PlantSimEngine.Evaluation.RMSE(y, y2), digits=3)

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
