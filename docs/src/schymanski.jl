# Compare simulations with measurements from Schymanski et al. (2017) extracted from this
# Github [repository](https://github.com/schymans/Schymanski_leaf-scale_2016).

using PlantBiophysics
using DataFrames
using CSV
using Plots

# Some constants used in the experiment:
maxiter = 20 # Maximum number of iterations for the algorithm to converge
aₛᵥ = 1 # number of sides used for transpiration (hypostomatous: 1, amphistomatous: 2)
cst = Constants(Cₚ = 1004.834)
A = 20.0 # Not used.

# Defining key functions:
function read_dict(file)
    lines = readlines(file)
    params = Dict{String,Float64}()
    for i in 1:length(lines)
        param = lstrip.(rstrip.(split(lines[i],"=")))
        push!(params, param[1] => parse(Float64,param[2]))
    end
    params
end

function run_simulation!(data,params,aₛᵥ)
    data[!, :Tₗ] .= data[!, :λE] .= data[!, :H] .= data[!, :rbh] .= 0.0
    data[!, :Rn] .= 0.0

    for i in 1:size(data,1)
        meteo = Atmosphere(T = Float64(data.T_a[i]) - params["T0"],
                            Wind = Float64(data.v_w[i]),
                            P = data.P_a[i] / 1000,
                            Rh = data.rh[i])
        leaf = LeafModels(energy = Monteith(aₛᵥ = aₛᵥ, maxiter = maxiter),
                    photosynthesis = ConstantA(A),
                    stomatal_conductance = ConstantGs(0.0, gsw_to_gsc(ms_to_mol(data.g_sw[i],data.T_a[i] - params["T0"],data.P_a[i]/1000))),
                    Rn = data.Rn_leaf[i], skyFraction = 2.0, d = data.L_l[i])
        out = energy_balance(leaf,meteo,cst)

        data.Tₗ[i] = out.Tₗ
        data.λE[i] = out.λE
        data.H[i] = out.H
        data.Rn[i] = out.Rn
        data.rbh[i] = 1/out.Gbₕ
    end
    data
end


### Figure 6 a of the article:

# Import the inputs for simulation:
results1_6a = DataFrame(CSV.File("data/schymanski_et_al_2017/results1_6a.csv"))
results1_6a.rh = rh_from_e.(results1_6a.P_wa ./ 1000.0, results1_6a.T_a .+ cst.K₀)
sort!(results1_6a, [:v_w])

# Reading the parameters:
params = read_dict("data/schymanski_et_al_2017/vdict_6a.txt")

# Running the simulation:
run_simulation!(results1_6a,params,aₛᵥ)

scatter(results1_6a.v_w, results1_6a.Elmeas, ylim = (-400,400),
        ylab = "Energy flux from leaf (W m-2)",legend=:inline,
        xlab = "Wind speed (m s-1)", label = "LE meas", color = "blue")
scatter!(results1_6a.v_w, results1_6a.Hlmeas,label = "H meas", color = "red")
scatter!(results1_6a.v_w, results1_6a.Rn_leaf,label = "Rn meas", color = "green")
scatter!(results1_6a.v_w, results1_6a.Hlmeas + results1_6a.Elmeas,label = "H+LE meas", color = "green", shape = :star5)
plot!(results1_6a.v_w, results1_6a.H,label = "H sim", color = "red")
plot!(results1_6a.v_w, results1_6a.λE,label = "LE sim", color = "blue")
plot!(results1_6a.v_w, results1_6a.Rn,label = "Rn sim", color = "green")
savefig("schymanski_et_al_2017_6a.svg")
