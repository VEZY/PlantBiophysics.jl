# Defining a list of models without status:
@testset "ModelList with no status" begin
    leaf = ModelList(
        photosynthesis=Fvcb(),
        stomatal_conductance=Medlyn(0.03, 12.0)
    )

    inits = init_variables(leaf.models...)
    st = MutableNamedTuple{keys(inits)}(values(inits))
    @test all(getproperty(leaf.status.vars, i) == getproperty(st, i) for i in keys(st))
end;


@testset "ModelList with a partially initialized status" begin
    leaf = ModelList(
        photosynthesis=Fvcb(),
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=(PPFD=15.0,)
    )

    inits = init_variables(leaf.models...)
    st = MutableNamedTuple{keys(inits)}(values(inits))
    st.PPFD = 15.0
    @test all(getproperty(leaf.status.vars, i) == getproperty(st, i) for i in keys(st))

    @test !is_initialised(leaf)
    @test to_initialise(leaf) == (:Tₗ, :Cₛ, :Dₗ)
end;

@testset "ModelList with fully initialized status" begin
    vals = (PPFD=15.0, Dₗ=0.3, Cₛ=400.0, Tₗ=15.0)
    leaf = ModelList(
        photosynthesis=Fvcb(),
        stomatal_conductance=Medlyn(0.03, 12.0),
        status=vals
    )

    inits = init_variables(leaf.models...)
    st = MutableNamedTuple{keys(inits)}(values(inits))

    for i in keys(vals)
        setproperty!(st, i, getproperty(vals, i))
    end
    @test all(getproperty(leaf.status.vars, i) == getproperty(st, i) for i in keys(st))

    @test is_initialised(leaf)
    @test to_initialise(leaf) == ()
end;
