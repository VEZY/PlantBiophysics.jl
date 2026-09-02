constants = Constants()
A = 20.0
Cₛ = 300.0
meteo = Atmosphere(
    T=28.0,
    Wind=0.8333,
    P=101.325,
    Rh=0.47,
    duration=Hour(1),
)

@testset "Medlyn et al. (2011)" begin
    scene = leaf_scene(
        Medlyn(0.03, 12.0, 0.0);
        status=Status(A=A, Cₛ=Cₛ, Dₗ=meteo.VPD),
        environment=meteo,
    )
    run!(scene; constants=constants)
    @test leaf_status(scene).Gₛ ≈ 0.6607197172920005
end

@testset "Constant stomatal conductance" begin
    scene = leaf_scene(ConstantGs(0.0, 0.2); environment=meteo)
    run!(scene; constants=constants)
    @test leaf_status(scene).Gₛ == 0.2
end

@testset "Tuzet et al. (2003)" begin
    values = map((0.0, -1.0, -2.0)) do Ψₗ
        scene = leaf_scene(
            Tuzet(0.03, 12.0, -1.5, 2.0, 30.0);
            status=Status(A=A, Cₛ=Cₛ, Ψₗ=Ψₗ),
            environment=meteo,
        )
        run!(scene; constants=constants)
        return leaf_status(scene).Gₛ
    end
    @test collect(values) ≈
          [0.918888888888889, 0.7121829707245958, 0.2809610900468388]
end
