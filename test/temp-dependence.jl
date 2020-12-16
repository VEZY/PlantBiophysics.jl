# Importing the physical constants:
constants = Constants()

T = 28.0 - constants.K₀ # Current temperature
Tᵣ = 25.0 - constants.K₀ # Reference temperature
A = Fvcb()

@testset "Γ_star()" begin
    @test PlantBiophysics.Γ_star(T,Tᵣ,constants) ==
        PlantBiophysics.arrhenius(42.75,37830.0,T,Tᵣ,constants)
end;

@testset "standard arrhenius()" begin
    @test PlantBiophysics.arrhenius(42.75,37830.0,T,Tᵣ,constants) ≈ 49.76935360399572
end;

@testset "arrhenius() with negative effect of too high T" begin
    @test PlantBiophysics.arrhenius(A.JMaxRef,A.Eₐⱼ,T,Tᵣ,constants,A.Hdⱼ,A.Δₛⱼ) ≈ 278.5161762418
    # NB: value checked using plantecophys.
end;

@testset "arrhenius() with negative effect of too high T" begin
    @test PlantBiophysics.arrhenius(A.JMaxRef,A.Eₐⱼ,T,Tᵣ,constants,A.Hdⱼ,A.Δₛⱼ) ≈ 278.5161762418
    # NB: value checked using plantecophys.
end;

@testset "compare arrhenius() implementations" begin
# arrhenius with negative effect of too high T should yield the same result as the standard Arrhenius
# when Δₛ = 0.0
    @test PlantBiophysics.arrhenius(A.JMaxRef,A.Eₐⱼ,28.0-constants.K₀,A.Tᵣ-constants.K₀,constants,A.Hdⱼ,0.0) ==
        PlantBiophysics.arrhenius(A.JMaxRef,A.Eₐⱼ,28.0-constants.K₀,A.Tᵣ-constants.K₀,constants)
end;
