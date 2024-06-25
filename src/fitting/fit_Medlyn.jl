"""
    fit(::Type{Medlyn}, df)

Optimize the parameters of the [`Medlyn`](@ref) model. Note that here Gₛ is stomatal conductance for CO2, not H2O.

Careful, g0 and g1 are fitted on CO₂ stomatal conductance, and so are given for CO₂, not H₂O.
If you want to compare the values with the ones usually given in the literature, you need to multiply g0 and g1 by 1.57.

# Arguments

- df: a DataFrame with columns A, Dₗ, Cₐ and Gₛ, where each row is an observation. The column
names should match exactly.

Note that Dₗ is the leaf to air vapour pressure deficit, computed as follows:

```julia
Dₗ = PlantMeteo.e_sat(Tₗ) - PlantMeteo.e_sat(T) * Rh
```

with Tₗ the leaf temperature, T the air temperature and Rh the air relative humidity. If Tₗ is not available, you can use Tₗ = T as a crude approximation,
which gives Dₗ = VPD.

# Examples

```julia
using PlantBiophysics, PlantMeteo, Plots, DataFrames

file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P1F20129.csv")
df = read_walz(file)
# Removing the CO2 and ligth Curve, we fit the parameters on the Rh curve:
filter!(x -> x.curve != "ligth Curve" && x.curve != "CO2 Curve", df)

# Fit the parameters values:
g0, g1 = fit(Medlyn, df)

# Re-simulating Gₛ using the newly fitted parameters:
w = Weather(select(df, :T, :P, :Rh, :Cₐ, :VPD, :T => (x -> 10) => :Wind))
leaf = ModelList(
        stomatal_conductance = Medlyn(g0, g1),
        status = (A = df.A, Cₛ = df.Cₐ, Dₗ = df.Dₗ)
    )
run!(leaf, w)

# Visualising the results:
gsAvpd = PlantBiophysics.GsADₗ(g0, g1, df.Gₛ, df.Dₗ, df.A, df.Cₐ, leaf[:Gₛ])
plot(gsAvpd,leg=:bottomright)
# As in [`Medlyn`](@ref) reference paper, linear regression is also plotted.
```
"""
function PlantSimEngine.fit(::T, df) where {T<:Type{Medlyn}}
    # Fitting the A/(Cₐ√Dₗ) - Gₛ curve using least squares method
    x = df.A ./ df.Cₐ
    y = sqrt.(df.Dₗ)
    Gₛ = df.Gₛ
    y = y[x.>0.0]
    Gₛ = Gₛ[x.>0.0]
    x = x[x.>0.0]


    # Changing the problem from Gₛ = g₀ + (1 + g₁/√Dₗ)*A/Cₐ to Gₛ - A/Cₐ = g₀ + g₁*A/(Cₐ*√Dₗ)
    A = [ones(length(x)) x ./ y]
    f = Gₛ .- x
    g0, g1 = inv(A' * A) * A' * f

    return (; g0, g1)
end

# Plot recipes for making A/(Cₐ √Dₗ)-Gₛ curves:
mutable struct GsADₗ
    g0
    g1
    gs_meas
    Dₗ_meas
    A_meas
    Cₐ_meas
    gs_sim
end

GsADₗ(g0, g1, gs_meas, Dₗ_meas, A_meas, Cₐ_meas) = GsADₗ(g0, g1, gs_meas, Dₗ_meas, A_meas, Cₐ_meas, copy(gs_meas))

@recipe function f(h::GsADₗ)
    x = h.A_meas ./ (h.Cₐ_meas .* sqrt.(h.Dₗ_meas))
    y = h.gs_meas
    y2 = h.gs_sim
    # Main plot (measurement):
    xguide --> "A/(Cₐ√Dₗ) (ppm)"
    yguide --> "gₛ (mol m⁻² s⁻¹)"

    EF_ = round(PlantSimEngine.EF(y, y2), digits=3)
    dr_ = round(PlantSimEngine.dr(y, y2), digits=3)
    RMSE_ = round(PlantSimEngine.RMSE(y, y2), digits=3)

    m(t, p) = p[1] .+ t .* p[2]
    p0 = [0.1, 1.0]
    linearfit = curve_fit(m, x, y, p0)
    y3 = linearfit.param[1] .+ linearfit.param[2] .* x

    @series begin
        seriestype := :line
        linealpha := 0.4
        linestyle := :dash
        linecolor := :black
        linewidth := 2
        dpi := 300
        label := "Linear regression"
        x, y3
    end

    @series begin
        seriestype := :scatter
        markercolor := :black
        markeralpha := 0.7
        dpi := 300
        label := "Measured"
        x, y
    end

    @series begin
        label := "Simulated (EF:$EF_,dr:$dr_,RMSE:$RMSE_)"
        markercolor := :white
        seriestype := :scatter
        markeralpha := 1.0
        markerstrokealpha := 1.0
        dpi := 300
        x, y2
    end
end
