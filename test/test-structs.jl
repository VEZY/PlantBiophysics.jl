
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


using CSV

# NOTE(Samuel): this test checking outputs as DataFrames is mostly obsolete as statuses are Status objects, and not TimeStepTables
# HOWEVER, it does test for providing a DataFrame as a Status, which is now unusual behaviour
# Usually only some values are initialized fully and provided as vectors, so we don't usually get a Tables-like input for the status
# So keeping it and renaming it
@testset "Inputs as DataFrame" begin
    st = (:Ra_SW_f => [13.747, 13.8], :sky_fraction => [1.0, 1.0], :d => [0.03, 0.03], :aPPFD => [1300.0, 1500.0])
    df = DataFrame(:Ra_SW_f => [13.747, 13.8], :sky_fraction => [1.0, 1.0], :d => [0.03, 0.03], :aPPFD => [1300.0, 1500.0])

    # Reference ModelList
    m =  ModelList(
        energy_balance=Monteith(),
        photosynthesis=Fvcb(α=0.24), # because I set-up the tests with this value for α
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=df  #st
        )

    m2 = ModelList(
        energy_balance=Monteith(),
        photosynthesis=Fvcb(α=0.24), # because I set-up the tests with this value for α
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=st
        )

    meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65)
    constants = Constants()

    out_st = run!(m, meteo, constants, nothing) # 1.525 μs
    out_df = run!(m2, meteo, constants, nothing) # 1.525 μs
    df_st = PlantSimEngine.convert_outputs(out_st, DataFrame)
    df_df = PlantSimEngine.convert_outputs(out_df, DataFrame)
    @test df_df == df_st
end;