
T = 28.0  # Current temperature
Tᵣ = 25.0 # Reference temperature

@testset "Γ_star()" begin
    @test Γ_star(T,Tᵣ,Constants()) == PlantBiophysics.arrhenius(42.75,37830.0,T,Tᵣ,Constants())
end;


@testset "arrhenius()" begin
    @test PlantBiophysics.arrhenius(42.75,37830.0,28.0,25.0,Constants()) ≈ 49.76935360399572
end;
