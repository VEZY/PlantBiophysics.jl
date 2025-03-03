
@testset "Uncertainty propagation basic check" begin
    unsafe_comparisons(true)
    meteo = Atmosphere(T=22.0 ± 0.1, Wind=0.8333 ± 0.1, P=101.325 ± 1.0, Rh=0.4490995 ± 0.02, Cₐ=400.0 ± 1.0)

    leaf = ModelList(
        Monteith(),
        Fvcb(),
        Medlyn(0.03, 12.0),
        status=(Ra_SW_f=13.747 ± 1.0, sky_fraction=1.0, aPPFD=1500.0 ± 1.0, d=0.03 ± 0.001),
        type_promotion=Dict(Float64 => Particles{Float64,2000})
    )

    @test_nowarn out_sim = run!(leaf, meteo)
end