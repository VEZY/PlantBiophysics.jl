
# Testing the ModelList struct
A = Fvcb()
g0 = 0.03;
g1 = 12.0;
Gs = Medlyn(g0, g1) # Instance of a Medlyn type with g0 = 0.03 and g1 = 0.1

@testset "ModelList()" begin
    leaf = ModelList(photosynthesis=A, stomatal_conductance=Gs)
    @test typeof(leaf) <: ModelList
    @test typeof(leaf.models.photosynthesis) == Fvcb{Float64}
    @test typeof(leaf.models.stomatal_conductance) == Medlyn{Float64}
    @test leaf.models.photosynthesis.Tᵣ == 25.0
    @test leaf.models.stomatal_conductance.g0 ≈ g0
    @test leaf.models.stomatal_conductance.g1 ≈ g1
end;


@testset "init_status!" begin
    leaf = ModelList(photosynthesis=A, stomatal_conductance=Gs)
    @test leaf.status.Tₗ == [-Inf]

    init_status!(leaf, Tₗ=25.0)
    @test leaf.status.Tₗ == [25.0]

    file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "models", "plant_coffee.yml")
    model = read_model(file)
    init_status!(model, Tₗ=25.0)
    @test model["Leaf"].status.Tₗ == [25.0]
end;


@testset "Vars to initialize" begin
    leaf = ModelList(photosynthesis=A, stomatal_conductance=Gs)
    @test to_initialize(leaf) == (photosynthesis=(:PPFD, :Dₗ, :Tₗ, :Cₛ),)
    @test to_initialize(leaf) == to_initialize(photosynthesis=A, stomatal_conductance=Gs)
    @test to_initialize(photosynthesis=A) == (photosynthesis=(:PPFD, :Tₗ, :Cₛ),)

    @test leaf.status.Tₗ == [-Inf]
    @test is_initialized(leaf) == false

    leaf =
        ModelList(
            photosynthesis=A,
            stomatal_conductance=Gs,
            status=(Tₗ=25.0, PPFD=1000.0, Cₛ=400.0, Dₗ=1.2)
        )

    @test is_initialized(leaf) == true
end;
