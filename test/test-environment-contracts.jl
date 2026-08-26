@testset "Declared environment inputs" begin
    @test Tuple(environment_inputs(Beer(0.5))) == (:Ri_PAR_f,)
    @test Tuple(environment_inputs(BeerShortwave(0.5))) == (:Ri_PAR_f, :Ri_NIR_f)
    @test Tuple(environment_inputs(FvcbIter())) == (:Cₐ,)
    @test Tuple(environment_inputs(Monteith())) ==
          (:T, :Cₐ, :Rh, :P, :ε, :Wind, :γ, :VPD, :Δ, :ρ)
end

@testset "Environment diagnostics precede numerical execution" begin
    @test validate_environment_inputs(
        (light=Beer(0.5),),
        (Ri_PAR_f=300.0,),
    ) === nothing
    @test_throws "Ri_PAR_f" validate_environment_inputs(
        (light=Beer(0.5),),
        NamedTuple(),
    )

    @test validate_environment_inputs(
        (light=BeerShortwave(0.5),),
        (Ri_PAR_f=300.0, Ri_NIR_f=280.0),
    ) === nothing
    @test_throws "Ri_NIR_f" validate_environment_inputs(
        (light=BeerShortwave(0.5),),
        (Ri_PAR_f=300.0,),
    )

    @test validate_environment_inputs(
        (photosynthesis=FvcbIter(),),
        (Cₐ=400.0,),
    ) === nothing
    @test_throws "Cₐ" validate_environment_inputs(
        (photosynthesis=FvcbIter(),),
        NamedTuple(),
    )

    complete_monteith_environment = (
        T=20.0,
        Cₐ=400.0,
        Rh=0.65,
        P=101.3,
        ε=0.8,
        Wind=1.0,
        γ=0.067,
        VPD=0.8,
        Δ=0.14,
        ρ=1.2,
    )
    @test validate_environment_inputs(
        (energy_balance=Monteith(),),
        complete_monteith_environment,
    ) === nothing
    @test_throws "Wind" validate_environment_inputs(
        (energy_balance=Monteith(),),
        Base.structdiff(complete_monteith_environment, NamedTuple{(:Wind,)}),
    )
end
