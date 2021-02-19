
# Testing the Leaf struct
A = Fvcb()
g0 = 0.03; g1 = 12.0
Gs = Medlyn(g0,g1) # Instance of a Medlyn type with g0 = 0.03 and g1 = 0.1

@testset "Leaf()" begin
    leaf = Leaf(photosynthesis = A, stomatal_conductance = Gs)
    @test typeof(leaf) == Leaf{Missing,Missing,Fvcb{Float64},Medlyn{Float64},
    MutableNamedTuples.MutableNamedTuple{(:A, :Gₛ, :Cᵢ, :Tₗ, :PPFD, :Cₛ, :Dₗ),
    NTuple{7,Base.RefValue{Float64}}}}

    @test typeof(leaf.photosynthesis) == Fvcb{Float64}
    @test typeof(leaf.stomatal_conductance) == Medlyn{Float64}
    @test leaf.photosynthesis.Tᵣ == 25.0
    @test leaf.stomatal_conductance.g0 ≈ g0
    @test leaf.stomatal_conductance.g1 ≈ g1
end;
