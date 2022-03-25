"""
    fit(::Type{Medlyn}, df)

Optimize the parameters of the [`Medlyn`](@ref) model. Note that here Gₛ is stomatal conductance for CO2, not H2O.

# Arguments

- df: a DataFrame with columns A, VPD, Cₐ and Gₛ, where each row is an observation. The column
names should match exactly.

# Examples

```julia
using PlantBiophysics, Plots, DataFrames

file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P1F20129.csv")
df = read_walz(file)
# Removing the CO2 and Rh curves 
filter!(x -> x.curve != "Rh Curve" && x.curve != "CO2 Curve", df)

# Fit the parameters values:
g0, g1 = fit(Medlyn, df)

# Re-simulating Gₛ using the newly fitted parameters:
gs_sim = g0 .+ (1 .+g1./sqrt.(df.VPD)).*df.A./df.Cₐ

# Visualising the results:
gsAvpd = PlantBiophysics.GsAVPD(g0, g1, df.gs, df.VPD, df.A, df.Cₐ, gs_sim)
plot(gsAvpd,leg=:bottomright)
# As in [`Medlyn`](@ref) reference paper, linear regression is also plotted.
```
"""
function fit(::T, df) where {T<:Union{Type{Medlyn}}}
    # Fitting the A/(Cₐ√Dₗ) - Gₛ curve using least squares method
    x = df.A ./ df.Cₐ
    y = sqrt.(df.VPD)
    gs = df.gs
    y=y[x.>0.]
    gs=gs[x.>0.]
    x=x[x.>0.]


    # Changing the problem from gs = g₀ + (1 + g₁/√Dₗ)*A/Cₐ to gs - A/Cₐ = g₀ + g₁*A/(Cₐ*√Dₗ)
    A = [ones(length(x)) x ./y]
    f = gs .- x
    g0,g1 = inv(A'*A)*A'*f

    return (g0, g1)
end

# Plot recipes for making A/(Cₐ √VPD)-Gₛ curves:
mutable struct GsAVPD
    g0
    g1
    gs_meas
    VPD_meas
    A_meas
    Cₐ_meas
    gs_sim
end

GsAVPD(g0, g1, gs_meas, VPD_meas, A_meas, Cₐ_meas) = GsAVPD(g0, g1, gs_meas, VPD_meas, A_meas, Cₐ_meas, copy(gs_meas))

@recipe function f(h::GsAVPD)
    x = h.A_meas ./ (h.Cₐ_meas .* sqrt.(h.VPD_meas))
    y = h.gs_meas
    y2 = h.gs_sim
    # Main plot (measurement):
    xguide --> "A/(Cₐ√VPD) (ppm)"
    yguide --> "gₛ (mol m⁻² s⁻¹)"

    EF_ = round(EF(y, y2), digits = 3)
    dr_ = round(dr(y, y2), digits = 3)
    RMSE_ = round(RMSE(y, y2), digits = 3)

    m(t,p) = p[1] .+ t .* p[2]
    p0 = [0.1, 1.0]
    linearfit = curve_fit(m,x,y,p0)
    y3 = linearfit.param[1] .+ linearfit.param[2].*x

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
        markeralpha := 1.
        markerstrokealpha := 1.
        dpi := 300
        x, y2
    end
end