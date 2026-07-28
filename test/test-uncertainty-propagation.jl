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
    scene = leaf_scene(
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
    )
    @test_nowarn run!(scene; constants=Constants())
end
