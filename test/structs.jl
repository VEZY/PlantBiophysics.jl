
# Testing the LeafModels struct
A = Fvcb()
g0 = 0.03; g1 = 12.0
Gs = Medlyn(g0,g1) # Instance of a Medlyn type with g0 = 0.03 and g1 = 0.1

@testset "LeafModels()" begin
    leaf = LeafModels(photosynthesis = A, stomatal_conductance = Gs)
    @test typeof(leaf) == LeafModels{Missing,Missing,Fvcb{Float64},Medlyn{Float64},
        MutableNamedTuples.MutableNamedTuple{(:PPFD, :Tₗ, :Cₛ, :A, :Gₛ, :Cᵢ, :Dₗ),
        NTuple{7,Base.RefValue{Float64}}}}

    @test typeof(leaf.photosynthesis) == Fvcb{Float64}
    @test typeof(leaf.stomatal_conductance) == Medlyn{Float64}
    @test leaf.photosynthesis.Tᵣ == 25.0
    @test leaf.stomatal_conductance.g0 ≈ g0
    @test leaf.stomatal_conductance.g1 ≈ g1
end;


@testset "Initialisations" begin
    leaf = LeafModels(photosynthesis = A, stomatal_conductance = Gs)
    @test leaf.status.Tₗ == 0.0

    init_status!(leaf, Tₗ = 25.0)
    @test leaf.status.Tₗ == 25.0

    model = read_model("inputs/models/plant_coffee.yml")
    init_status!(model, Tₗ = 25.0)
    @test model["Leaf"].status.Tₗ == 25.0
end;
