using Test, Dates
using PlantBiophysics, PlantSimEngine, PlantMeteo

@testset "Alternative electron and gas transport" begin
    photons = 0.32 * 600.0
    @test get_J(600.0, 120.0, 0.32, 0.0) ≈
        photons * 120.0 / (photons + 120.0)
    @test get_J(600.0, 120.0, 0.32, 0.001) ≈
        get_J(600.0, 120.0, 0.32, 0.0) rtol=0.001

    atmosphere = Atmosphere(T=25.0, Wind=1.0, P=101.3, Rh=1.0,
        Cₐ=400.0, duration=Hour(1))
    base = Fvcb(VcMaxRef=70.0, JMaxRef=120.0, RdRef=0.6, α=0.32)
    status() = Status(aPPFD=600.0, Tₗ=25.0, Cₛ=400.0, Dₗ=1.0,
        A=-Inf, Cᵢ=-Inf, Gₛ=-Inf, Gₗw=-Inf)

    fick = FvcbMechanisms(;base,g0w=0.0256,g1=2.0)
    zero_cuticle = FvcbMechanisms(;base,g0w=0.0256,g1=2.0,
        gas_transport=:marquez,gcw=0.0)
    s1, s2 = status(), status()
    PlantSimEngine.run!(fick,s1,atmosphere)
    PlantSimEngine.run!(zero_cuticle,s2,atmosphere)
    @test all(isapprox(getproperty(s1, v), getproperty(s2, v); rtol=1e-8)
        for v in (:A, :Cᵢ, :Gₛ, :Gₗw))

    cuticle = FvcbMechanisms(;base,g0w=0.0256,g1=2.0,
        gas_transport=:marquez,gcw=0.005)
    s3 = status()
    PlantSimEngine.run!(cuticle,s3,atmosphere)
    @test isfinite(s3.A) && isfinite(s3.Cᵢ)
    @test s3.Gₗw - 1.6*s3.Gₛ ≈ 0.005 atol=1e-12

    cb_standard = FvcbMechanisms(;base,electron_transport=:cytochrome,
        Cb6fMaxRef=90.0,g0w=0.0256,g1=2.0)
    cb_thermal = FvcbMechanisms(;base,electron_transport=:cytochrome,
        temperature_response=:cytochrome,Cb6fMaxRef=90.0,g0w=0.0256,g1=2.0)
    s4, s5 = status(), status()
    PlantSimEngine.run!(cb_standard,s4,atmosphere)
    PlantSimEngine.run!(cb_thermal,s5,atmosphere)
    @test s4.A ≈ s5.A atol=1e-8

    @test_throws ArgumentError FvcbMechanisms(electron_transport=:unknown)
    @test_throws ArgumentError FvcbMechanisms(g0w=0.002,gcw=0.005)

    scene = CompositeModel(Monteith(maxiter=200),cuticle;
        status=Status(aPPFD=600.0,Ra_SW_f=110.0,sky_fraction=2.0,d=0.03),
        environment=Atmosphere(T=25.0,Wind=1.0,P=101.3,Rh=0.6,
            Cₐ=400.0,duration=Hour(1)))
    PlantSimEngine.run!(scene)
    leaf = only(model_objects(scene)).status
    @test isfinite(leaf.λE) && isfinite(leaf.Gₗw)
    @test abs(leaf.Rn-leaf.H-leaf.λE) < 1e-8
end
