
# Testing the ModelList struct
A = Fvcb(α=0.24) # because I set-up the tests with this value for α
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
    @test leaf.status.Tₗ == -Inf

    PlantSimEngine.init_status!(leaf, Tₗ=25.0)
    @test leaf.status.Tₗ == 25.0
end;


@testset "Vars to initialize" begin
    leaf = ModelList(photosynthesis=A, stomatal_conductance=Gs)
    @test to_initialize(leaf) == (photosynthesis=(:aPPFD, :Tₗ, :Cₛ), stomatal_conductance=(:Dₗ, :Cₛ))
    @test to_initialize(leaf) == to_initialize(photosynthesis=A, stomatal_conductance=Gs)
    @test to_initialize(photosynthesis=A) == (photosynthesis=(:aPPFD, :Tₗ, :Cₛ),)

    @test leaf.status.Tₗ == -Inf
    @test is_initialized(leaf) == false

    leaf =
        ModelList(
            photosynthesis=A,
            stomatal_conductance=Gs,
            status=(Tₗ=25.0, aPPFD=1000.0, Cₛ=400.0, Dₗ=1.2)
        )

    @test is_initialized(leaf) == true
end;


@testset "Outputs as DataFrame" begin
    st = (:Ra_SW_f => [13.747, 13.8], :sky_fraction => [1.0, 1.0], :d => [0.03, 0.03], :aPPFD => [1300.0, 1500.0])

    # Reference ModelList
    m = ModelList(
        energy_balance=Monteith(),
        photosynthesis=Fvcb(α=0.24), # because I set-up the tests with this value for α
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=st
    )

    meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65)
    constants = Constants()

    out = run!(m, meteo, constants, nothing) # 1.525 μs
    
    out_df = convert_outputs(out, DataFrame)

    @test DataFrame(out) == out_df
    @test out_df == DataFrame(out)
end;