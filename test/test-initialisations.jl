# Defining a list of models without status:
@testset "ModelList with no status" begin
    leaf = ModelList(
        photosynthesis=Fvcb(),
        stomatal_conductance=Medlyn(0.03, 12.0)
    )

    inits = merge(init_variables(leaf.models)...)
    st = MutableNamedTuple{keys(inits)}(values(inits))
    @test all(getproperty(leaf.status, i) == getproperty(st, i) for i in keys(st))
end;


@testset "ModelList with a partially initialized status" begin
    leaf = ModelList(
        photosynthesis=Fvcb(),
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=(PPFD=15.0,)
    )

    inits = merge(init_variables(leaf.models)...)
    st = MutableNamedTuple{keys(inits)}(values(inits))
    st.PPFD = 15.0
    @test all(getproperty(leaf.status, i) == getproperty(st, i) for i in keys(st))

    @test !is_initialized(leaf)
    @test to_initialize(leaf) == (photosynthesis=(:Dₗ, :Tₗ, :Cₛ),)
end;

@testset "ModelList with fully initialized status" begin
    vals = (PPFD=15.0, Dₗ=0.3, Cₛ=400.0, Tₗ=15.0)
    leaf = ModelList(
        photosynthesis=Fvcb(),
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=vals
    )

    inits = merge(init_variables(leaf.models)...)
    st = MutableNamedTuple{keys(inits)}(values(inits))

    for i in keys(vals)
        setproperty!(st, i, getproperty(vals, i))
    end
    @test all(getproperty(leaf.status, i) == getproperty(st, i) for i in keys(st))

    @test is_initialized(leaf)
    @test to_initialize(leaf) == NamedTuple()
end;


@testset "ModelList with independant models (and missing one in the middle)" begin
    vals = (PPFD=15.0, Dₗ=0.3, Cₛ=400.0, Tₗ=15.0)
    leaf = ModelList(
        energy_balance=Monteith(),
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=vals
    )

    @test to_initialize(leaf) == (energy_balance=(:d, :sky_fraction, :Rₛ), stomatal_conductance=(:A,))

    # NB: decompose this test because the order of the variables change with the Julia version
    inits = init_variables(leaf)
    sorted_vars_energy = sort([keys(inits.energy_balance)...])

    @test [getfield(inits.energy_balance, i) for i in sorted_vars_energy] ==
          [-Inf, -Inf, -Inf, -Inf, -Inf, -Inf, -Inf, -Inf, -Inf, -Inf, -Inf, -Inf, -Inf, -9223372036854775808, -Inf, -Inf]

    sorted_vars_gs = sort([keys(inits.stomatal_conductance)...])
    @test [getfield(inits.stomatal_conductance, i) for i in sorted_vars_gs] ==
          [-Inf, -Inf, -Inf, -Inf]
end;
