
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


@testset "Status as DataFrame" begin

    df = DataFrame(:Rₛ => [13.747, 13.8], :sky_fraction => [1.0, 1.0], :d => [0.03, 0.03], :PPFD => [1300.0, 1500.0])
    m = ModelList(
        energy_balance=Monteith(),
        photosynthesis=Fvcb(),
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=df
    )

    meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65)
    constants = Constants()

    energy_balance!(m_df, meteo, constants) # 26.125 μs
    energy_balance!(m, meteo, constants) # 1.525 μs

    @test status(m_df) == DataFrame(status(m))
end;