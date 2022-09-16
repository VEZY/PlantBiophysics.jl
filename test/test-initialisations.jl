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

    @test init_variables(leaf) == (
        energy_balance=(
            Dₗ=-Inf, Tₗ=-Inf, Cᵢ=-Inf, Rn=-Inf, Cₛ=-Inf, d=-Inf, A=-Inf, sky_fraction=-Inf,
            Rₛ=-Inf, λE=-Inf, Rₗₗ=-Inf, iter=-9223372036854775808, H=-Inf, Gₛ=-Inf,
            Gbc=-Inf, Gbₕ=-Inf
        ),
        stomatal_conductance=(A=-Inf, Dₗ=-Inf, Gₛ=-Inf, Cₛ=-Inf)
    )

end;
