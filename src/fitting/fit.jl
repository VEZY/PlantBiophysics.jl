
"""
    fit(::Type{<:AbstractModel}, df; kwargs)

Optimize the parameters of a model using measurements in `df` and the initialisation values in
`kwargs`. Note that the columns in `df` should match exactly the names and units used in the
model. See particular implementations for more details.
"""
function fit end

"""
    fit(::Type{Fvcb}, df; Tᵣ = 25.0, VcMaxRef = 200.0, JMaxRef = 250.0, RdRef = 0.6)

Optimize the parameters of the [`Fvcb`](@ref) model. Also works for [`FvcbIter`](@ref).

# Examples

```julia
using Plots

file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P1F20129.csv")
df = read_walz(file)
# Removing the Rh and light curves for the fitting because temperature varies
filter!(x -> x.curve != "Rh Curve" && x.curve != "ligth Curve", df)
VcMaxRef, JMaxRef, RdRef, TPURef = fit(Fvcb, df; Tᵣ = 25.0, VcMaxRef = 200.0, JMaxRef = 250.0, RdRef = 0.6)
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
            photosynthesis = Fvcb(VcMaxRef = VcMaxRef, JMaxRef = JMaxRef, RdRef = RdRef, Tᵣ = 25.0, TPURef = TPURef),
            stomatal_conductance = ConstantGs(0.0, df[i,:gs]),
            Tₗ = df[i,:T], PPFD = df[i,:PPFD], Cₛ = df[i,:Cₐ])

    meteo = Atmosphere(T = df[i,:T], Wind = 10.0, P = df[i,:P], Rh = df[i,:Rh], Cₐ = df[i,:Cₐ])
    photosynthesis!(leaf, meteo)
A[i] = leaf.status.A
end

# Visualising
test = PlantBiophysics.ACi(VcMaxRef, JMaxRef, RdRef, df[:,:A], A, df[:,:Cᵢ])
plot(test)
```
"""
function fit(mod::Type{Fvcb}, df; Tᵣ = nothing, PPFD = nothing, VcMaxRef = 0., JMaxRef = 0., RdRef = 0., TPURef = 0.)
    # Sorting Cᵢ values to make sure that they increase
    ind = sortperm(df.Cᵢ)

    if Tᵣ === nothing
        Tᵣ = mean(df.Tleaf)
    end

    if PPFD === nothing
        PPFD =  mean(df.PPFD)
    end

    # Redefining the function Aₙ = f(Cᵢ) using used reference temperature and PPFD values
    model(Cᵢ, p) = A_Ci_function(mod, Cᵢ, Tᵣ, p[1], p[2], p[3], p[4], PPFD)

    # Fitting the A-Cᵢ curve using LsqFit.jl
    fits = curve_fit(model, df.Cᵢ[ind], df.A[ind], [VcMaxRef,JMaxRef,RdRef,TPURef])
    return (VcMaxRef = fits.param[1], JMaxRef = fits.param[2], RdRef = fits.param[3], TPURef = fits.param[4])
end

mutable struct ACi
    VcMaxRef
    JMaxRef
    RdRef
    A_meas
    A_sim
    Cᵢ
end

@recipe function f(h::ACi)
    x = h.Cᵢ
    y = h.A_meas
    y2 = h.A_sim
    # Main plot (measurement):
    xguide --> "Cᵢ (ppm)"
    yguide --> "A (μmol m⁻² s⁻¹)"

    EF_ = round(EF(y, y2), digits = 3)
    dr_ = round(dr(y, y2), digits = 3)
    RMSE_ = round(RMSE(y, y2), digits = 3)

    @series begin
        seriestype := :scatter
        label := "Measured"
        x, y
    end

    @series begin
        label := "Simulated (EF:$EF_,dr:$dr_,RMSE:$RMSE_)"
        seriestype := :line
        x, y2
    end
end

"""
    A_Ci_function(assim_model::Type{Fvcb},Cᵢ,Tₗ,VcMaxRef,JMaxRef,RdRef,TPURef,PPFD,constants=Constants())

Computes the net assimilation Aₙ as a function of Cᵢ, using the Farquhar–von Caemmerer–Berry (FvCB) model
for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981).

# Example
```julia
A_Ci_function(Fvcb,300.,25.,200.,200.,0.5,10.,1500.)
```
"""
function A_Ci_function(assim_model::Type{Fvcb}, Cᵢ, Tₗ, VcMaxRef, JMaxRef, RdRef, TPURef, PPFD, constants = Constants())
    parameters = defaults(assim_model)
    Tₖ =  Tₗ - constants.K₀
    Tᵣₖ = parameters.Tᵣ - constants.K₀
    Γˢ = Γ_star(Tₖ, Tᵣₖ, constants.R) # Gamma star (CO2 compensation point) in μmol mol-1
    Km = get_km(Tₖ, Tᵣₖ, parameters.O₂, constants.R) # effective Michaelis–Menten coefficient for CO2
    JMax = arrhenius(JMaxRef, parameters.Eₐⱼ, Tₖ, Tᵣₖ, parameters.Hdⱼ, parameters.Δₛⱼ, constants.R)
    VcMax = arrhenius(VcMaxRef, parameters.Eₐᵥ, Tₖ, Tᵣₖ, parameters.Hdᵥ, parameters.Δₛᵥ, constants.R)
    Rd = arrhenius(RdRef, parameters.Eₐᵣ, Tₖ, Tᵣₖ, constants.R)
    J = get_J(PPFD, JMax, parameters.α, parameters.θ) # in μmol m-2 s-1
    Vⱼ = J / 4
    Wⱼ = Vⱼ .* (Cᵢ .- Γˢ) ./ (Cᵢ .+ 2.0 .* Γˢ) # also called Aⱼ
    Wᵥ = VcMax .* (Cᵢ .- Γˢ) ./ (Cᵢ .+ Km)
    ag = 0.
    Wₚ = (Cᵢ .- Γˢ) .* 3 .* TPURef ./ (Cᵢ .- (1 .+ 3 .* ag) .* Γˢ)
    return min.(Wᵥ, Wⱼ, Wₚ) .- Rd
end
