# Compare simulations with measurements from Schymanski et al. (2017) extracted from this
# Github [repository](https://github.com/schymans/Schymanski_leaf-scale_2016).

using PlantBiophysics
using DataFrames
using CSV
using CairoMakie
CairoMakie.activate!(type="svg")

# Reading the parameters:
params = read_dict("../data/schymanski_et_al_2017/vdict_6a.txt")

# Some constants used in the experiment:
maxiter = 20 # Maximum number of iterations for the algorithm to converge
aₛᵥ = 1 # number of sides used for transpiration (hypostomatous: 1, amphistomatous: 2)
cst = Constants(
    Cₚ=1010.0, ε=params["epsilon"], λ₀=params["lambda_E"],
    R=params["R_mol"], σ=params["sigm"], Mₕ₂ₒ=params["M_w"]
)

# Defining key functions:
function read_dict(file)
    lines = readlines(file)
    params = Dict{String,Float64}()
    for i in eachindex(lines)
        param = lstrip.(rstrip.(split(lines[i], "=")))
        push!(params, param[1] => parse(Float64, param[2]))
    end
    params
end

### Figure 6 a of the article:

# Import the measurements:
results1_6a = CSV.read("../data/schymanski_et_al_2017/results1_6a.csv", DataFrame)

# Sort by Wind for plotting:
sort!(results1_6a, [:v_w])

# Compute the meteo:
w = select(
    results1_6a,
    :T_a => (x -> x .- params["T0"]) => :T,
    :v_w => :Wind,
    :P_a => (x -> x ./ 1000.0) => :P,
    [:P_wa, :T_a] => ((x, y) -> rh_from_e.(x ./ 1000.0, y .- params["T0"])) => :Rh,
    :P_wa => (x -> x ./ 1000.0) => :e
)

weather = Weather(w)

gs_obs = gsw_to_gsc.(ms_to_mol.(results1_6a.g_sw, results1_6a.T_a .- params["T0"], results1_6a.P_a ./ 1000))

# Just a trick to avoid computing any photosynthesis in our case:
PlantBiophysics.photosynthesis!_(leaf::ModelList, meteo, constant) = nothing

leaf = ModelList(
    energy_balance=Monteith(aₛᵥ=params["a_s"], maxiter=maxiter),
    status=(
        Rₛ=results1_6a.Rn_leaf,
        sky_fraction=2.0,
        d=results1_6a.L_l,
        Gₛ=gs_obs
    )
)

# NB, we use ConstantAGs and not ConstantA because Monteith calls the photosynthesis,
# not stomatal_conductance (stomatal_conductance is called inside the photosynthesis).
energy_balance!(leaf, weather, cst)

# Running the simulation:
size_inches = (8, 6)
size_pt = 72 .* size_inches
f = Figure(resolution=size_pt, fontsize=12)
ax = Axis(
    f[1, 1],
    xlabel=L"Wind speed ($m \cdot s^{-1}$)",
    ylabel=L"Energy flux from leaf ($W \cdot m^{-2}$)"
)
p1 = scatter!(ax, results1_6a.v_w, results1_6a.Elmeas, label="LE", color="#3D405B")
p2 = scatter!(ax, results1_6a.v_w, results1_6a.Hlmeas, label="H", color="#E07A5F")
p3 = scatter!(ax, results1_6a.v_w, results1_6a.Rn_leaf, label="Rn", color="#81B29A")
p4 = scatter!(ax, results1_6a.v_w, results1_6a.Hlmeas + results1_6a.Elmeas, label="H+LE", marker=:star5, color="#81B29A")
# Simulation:
p5 = lines!(ax, weather[:Wind], leaf[:H], label="H", color="#E07A5F")
p6 = lines!(ax, weather[:Wind], leaf[:λE], label="LE", color="#3D405B")
p7 = lines!(ax, weather[:Wind], leaf[:Rn], label="Rn", color="#81B29A")
Legend(
    f[2, 1],
    [p1, p2, p3, p4],
    ["LE", "H", "Rn", "H+LE"],
    orientation=:horizontal, labelsize=10, colgap=6
)

save("./schymanski_et_al_2017_6a.svg", f, pt_per_unit=1)
