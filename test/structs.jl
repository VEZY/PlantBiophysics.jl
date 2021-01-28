
# Testing the Leaf struct
A = Fvcb()
g0 = 0.03; g1 = 12.0
Gs = Medlyn(g0,g1) # Instance of a Medlyn type with g0 = 0.03 and g1 = 0.1

@testset "Leaf()" begin
    leaf = Leaf(A,Gs)
    @test typeof(leaf) == Leaf{Fvcb{Float64},Medlyn{Float64}}
    @test typeof(leaf.assimilation) == Fvcb{Float64}
    @test typeof(leaf.conductance) == Medlyn{Float64}
    @test leaf.assimilation.Tᵣ ≈ 25.0
    @test leaf.conductance.g0 ≈ g0
    @test leaf.conductance.g1 ≈ g1
end;
