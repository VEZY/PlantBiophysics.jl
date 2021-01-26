# Importing the physical constants:
constants = Constants()

T = 28.0 - constants.K₀ # Current temperature
Tᵣ = 25.0 - constants.K₀ # Reference temperature
A = Fvcb()


A = 20 # assimilation (umol m-2 s-1)
Cₛ = 300.0 # Stomatal CO₂ concentration (ppm)
Gs = Medlyn(0.03,12.0) # Instance of a Medlyn type with g0 = 0.03 and g1 = 0.1

# Computing the stomatal conductance using the Medlyn et al. (2011) model:

@testset "Medlyn et al. (2011)" begin
    @test gs(Gs,A,Cₛ,VPD = 2.0) ≈ 0.10138071187457699
end;

VPD = 0.1:0.1:3.0

plot(x -> gs(Gs,A,Cₛ,VPD = x), VPD, xlabel = "VPD (kPa)",
            ylab = "Gs (μmol m⁻² s⁻¹)",
            label = "A = 20, Cₛ = 300.0, g0 = 0.03, g1 = 12.0",
            legend = :topright)
plot!(x -> gs(Medlyn(0.03,15.0),A,Cₛ,VPD = x), VPD,
    label = "A = 20, Cₛ = 300.0, g0 = 0.03, g1 = 15.0")
plot!(x -> gs(Medlyn(0.01,12.0),A,Cₛ,VPD = x), VPD,
    label = "A = 20, Cₛ = 300.0, g0 = 0.01, g1 = 12.0")
plot!(x -> gs(Gs,15,Cₛ,VPD = x), VPD,
    label = "A = 15, Cₛ = 300.0, g0 = 0.03, g1 = 12.0")
plot!(x -> gs(Gs,A,200,VPD = x), VPD,
        label = "A = 20, Cₛ = 200.0, g0 = 0.01, g1 = 12.0")
