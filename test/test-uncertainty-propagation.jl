@testset "Uncertainty propagation basic check" begin
    unsafe_comparisons(true)
    meteo = Atmosphere(
        T=22.0 ± 0.1,
        Wind=0.8333 ± 0.1,
        P=101.325 ± 1.0,
        Rh=0.4490995 ± 0.02,
        Cₐ=400.0 ± 1.0,
        duration=Hour(1),
    )
    scene = CompositeModel(
        Monteith(),
        Fvcb(),
        Medlyn(0.03, 12.0);
        status=Status(
            Ra_SW_f=13.747 ± 1.0,
            sky_fraction=1.0,
            aPPFD=1500.0 ± 1.0,
            d=0.03 ± 0.001,
        ),
        environment=meteo,
        type_promotion=Dict(Float64 => Particles{Float64,2000}),
    )
    @test_nowarn run!(scene; constants=Constants())
    status = leaf_status(scene)
    for variable in (:Rn, :H, :λE, :Tₗ, :A, :Gₛ)
        value = status[variable]
        @test value isa Particles{Float64,2000}
        @test isfinite(pmean(value))
        @test isfinite(pstd(value)) && pstd(value) > 0.0
    end
end

@testset "Particle-valued model parameter and status carrier" begin
    assimilation = 25.0 ± 2.0
    scene = CompositeModel(
        ConstantA(assimilation);
        environment=(duration=Hour(1),),
        status_transform=(variable, value) ->
            variable === :A ? assimilation : value,
    )
    run!(scene)
    simulated = leaf_status(scene).A
    @test nparticles(simulated) == 2000
    @test pmean(simulated) ≈ 25.0
    @test pstd(simulated) ≈ pstd(assimilation)
end
