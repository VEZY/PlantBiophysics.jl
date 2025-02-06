# Importing the physical constants:
constants = Constants()

# Defining the variables we need:
A = 20.0 # assimilation (umol m-2 s-1)
Cₛ = 300.0 # Air CO₂ concentration at the leaf surface (ppm)
Gs = Medlyn(0.03, 12.0, 0.0) # Instance of a Medlyn type with g0 = 0.03 and g1 = 0.1

# Defining the meteorology:
meteo = Atmosphere(T=28.0, Wind=0.8333, P=101.325, Rh=0.47)

# Defining the leaf struct:
leaf = ModelList(
    stomatal_conductance=Gs, # Instance of a Medlyn type
    status=(A=A, Cₛ=Cₛ, Dₗ=meteo.VPD)
)

# Computing the stomatal conductance using the Medlyn et al. (2011) model:

@testset "Medlyn et al. (2011)" begin
    outputs = run!(leaf, meteo)
    @test outputs.Gₛ[1] ≈ 0.6607197172920005 # in mol[CO₂] m-2 s-1
end;


# VPD = 0.1:0.1:3.0
# plot(x -> stomatal_conductance(Gs,A,Cₛ,VPD = x), VPD, xlabel = "VPD (kPa)",
#             ylab = "Gs (μmol[CO₂] m⁻² s⁻¹)",
#             label = "A = 20, Cₛ = 300.0, g0 = 0.03, g1 = 12.0",
#             legend = :topright)
# plot!(x -> stomatal_conductance(Medlyn(0.03,15.0),A,Cₛ,VPD = x), VPD,
#     label = "A = 20, Cₛ = 300.0, g0 = 0.03, g1 = 15.0")
# plot!(x -> stomatal_conductance(Medlyn(0.01,12.0),A,Cₛ,VPD = x), VPD,
#     label = "A = 20, Cₛ = 300.0, g0 = 0.01, g1 = 12.0")
# plot!(x -> stomatal_conductance(Gs,15,Cₛ,VPD = x), VPD,
#     label = "A = 15, Cₛ = 300.0, g0 = 0.03, g1 = 12.0")
# plot!(x -> stomatal_conductance(Gs,A,200,VPD = x), VPD,
#         label = "A = 20, Cₛ = 200.0, g0 = 0.01, g1 = 12.0")
