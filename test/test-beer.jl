constants = Constants()
meteo = Atmosphere(
    T=20.0,
    Wind=1.0,
    P=101.3,
    Rh=0.65,
    Ri_PAR_f=300.0,
    duration=Hour(1),
)

@testset "Beer-Lambert" begin
    @test Beer <: AbstractLight_InterceptionModel
    scene = leaf_scene(
        Beer(0.5);
        status=Status(LAI=2.0),
        environment=meteo,
    )
    run!(scene; constants=constants)
    @test leaf_status(scene).aPPFD ≈
          300.0 * (1.0 - exp(-0.5 * 2.0)) * constants.J_to_umol
end
