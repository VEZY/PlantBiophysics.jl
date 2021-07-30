
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
filter!(x -> (x.curve != "Rh Curve")&(x.curve != "ligth Curve"), df)
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

test = PlantBiophysics.ACi(VcMaxRef, JMaxRef, RdRef, df[:,:A], A, df[:,:Cᵢ])
plot(test)

# Fitting data
params = fit(Fvcb,df)

# Visualising
visualise_fitting_photosynthesis(Fvcb,df,params)
```
"""
function fit(assim_model::Type{Fvcb}, df; Tᵣ = nothing, PPFD = nothing, VcMaxRef = 0., JMaxRef = 0., RdRef = 0., TPURef = 0.)
    # Sorting Cᵢ values to make sure that they increase
    ind = sortperm(df.Cᵢ)

    (Tᵣ === nothing) && (Tᵣ = mean(df.Tleaf))
    (PPFD === nothing) && (PPFD =  mean(df.PPFD))

    # Redefining the function Aₙ = f(Cᵢ) using used reference temperature and PPFD values
    model(Cᵢ,p) = A_Ci_function(assim_model,Cᵢ,Tᵣ,p[1],p[2],p[3],p[4],PPFD)

    # Fitting the A-Cᵢ curve using LsqFit.jl
    fits = curve_fit(model,df.Cᵢ[ind],df.A[ind],[VcMaxRef,JMaxRef,RdRef,TPURef])
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

    @series begin
        seriestype := :scatter
        label := "Measured"
        x, y
    end

    @series begin
        label := "Simulated"
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
function A_Ci_function(assim_model::Type{Fvcb},Cᵢ,Tₗ,VcMaxRef,JMaxRef,RdRef,TPURef,PPFD,constants=Constants())
    parameters = defaults(assim_model)
    Tₖ =  Tₗ - constants.K₀
    Tᵣₖ = parameters.Tᵣ - constants.K₀
    Γˢ = Γ_star(Tₖ, Tᵣₖ, constants.R) # Gamma star (CO2 compensation point) in μmol mol-1
    Km = get_km(Tₖ, Tᵣₖ, parameters.O₂, constants.R) # effective Michaelis–Menten coefficient for CO2
    JMax = arrhenius(JMaxRef,parameters.Eₐⱼ,Tₖ,Tᵣₖ,parameters.Hdⱼ,parameters.Δₛⱼ,constants.R)
    VcMax = arrhenius(VcMaxRef,parameters.Eₐᵥ,Tₖ,Tᵣₖ,parameters.Hdᵥ,parameters.Δₛᵥ,constants.R)
    Rd = arrhenius(RdRef, parameters.Eₐᵣ, Tₖ, Tᵣₖ, constants.R)
    J = get_J(PPFD, JMax, parameters.α, parameters.θ) # in μmol m-2 s-1
    Vⱼ = J / 4
    Wⱼ = Vⱼ .* (Cᵢ .- Γˢ) ./ (Cᵢ .+ 2.0 .* Γˢ) # also called Aⱼ
    Wᵥ = VcMax .* (Cᵢ .- Γˢ) ./ (Cᵢ .+ Km)
    ag = 0.
    Wₚ = (Cᵢ .- Γˢ) .* 3 .* TPURef ./ (Cᵢ .- (1 .+ 3 .* ag) .* Γˢ)
    return min.(Wᵥ, Wⱼ, Wₚ) .- Rd
end

"""
    visualise_fitting_photosynthesis(assim_model::Type{Fvcb},df,params)

Plots the A-Ci curve with measurements as points and simulations as line. `df` is the DataFrame containing all the needed measurement data
in the correct format and `params` is a Vector containing photosynthesis parameters (i.e. `params` = [VcMaxRef, JMaxRef, RdRef, TPURef]).

# Example
```julia
using Plots

file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","data","P1F20129.csv")
df = read_walz(file)
# Removing the Rh curve for the fitting because temperature varies
filter!(x -> (x.curve != "Rh Curve")&(x.curve != "ligth Curve"), df)

# Fitting
params = fit(Fvcb,df)

# Visualising
visualise_fitting_photosynthesis(Fvcb,df,params)
```
"""
function visualise_fitting_photosynthesis(assim_model::Type{Fvcb},df,params)
    ind = sortperm(df.Cᵢ)
    xdata = df.Cᵢ[ind]
    ydata = df.A[ind]
    ydata_sim = A_Ci_function.(assim_model,xdata,mean(df.Tleaf),params[1],params[2],params[3],params[4],mean(df.PPFD))
    EF1 = round(EF(ydata,ydata_sim),digits=3)
    dr1 = round(dr(ydata,ydata_sim),digits=3)
    RMSE1 = round(RMSE(ydata,ydata_sim),digits=3)
    Plots.scatter(xdata,ydata,label="meas.")
    Plots.plot!(xdata,ydata_sim,leg=:bottomright,label="sim. (EF=$EF1,dr=$dr1,RMSE=$RMSE1)")
    xlabel!("Cᵢ (ppm)")
    ylabel!("Aₙ")
end

"""
    RMSE(obs,sim)

    Returns the Root Mean Squared Error between observations `obs` and simulations `sim`.

    The closer to 0 the better.
"""
function RMSE(obs,sim)
    return sqrt(sum((obs .- sim).^2)/length(obs))
end

"""
    NRMSE(obs,sim)

    Returns the Normalized Root Mean Squared Error between observations `obs` and simulations `sim`.
    Normalization is performed using division by observations range (max-min).

    Output: Float/Particles
"""
function NRMSE(obs,sim)
    return sqrt(sum((obs .- sim).^2)/length(obs)) / (findmax(obs)[1]-findmin(obs)[1])
end

"""
    EF(obs,sim)

    Returns the Efficiency Factor between observations `obs` and simulations `sim` using NSE (Nash-Sutcliffe efficiency) model.
    More information can be found at https://en.wikipedia.org/wiki/Nash%E2%80%93Sutcliffe_model_efficiency_coefficient.

    The closer to 1 the better.
"""
function EF(obs,sim)
    SSres = sum((obs - sim).^2)
    SStot = sum((obs .- mean(obs)).^2)
    return 1-SSres/SStot
end

"""
    dr(obs,sim)

    Returns the Willmott’s refined index of agreement dᵣ. 
    Willmot et al. 2011. A refined index of model performance. https://rmets.onlinelibrary.wiley.com/doi/10.1002/joc.2419 

    The closer to 1 the better.

"""
function dr(obs,sim)
    a = sum(abs.(obs.-sim))
    b = 2*sum(abs.(obs.-mean(obs)))
    return 0 + (1-a/b)*(a <= b) + (b/a - 1)*(a>b)
end

"""
    mean(array)

    Returns the mean of a given array. Also disponible in the package `Statistics.jl`, but as far as
    we do not use other functions from `Statistics.jl`, and given the simplicity of the function, here it is.

"""
function mean(array)
    return sum(array)/length(array)
end