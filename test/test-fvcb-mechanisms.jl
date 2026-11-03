using Test, Dates
using PlantBiophysics, PlantSimEngine, PlantMeteo


# The same extension point as the documented BandB example, but its affine
# slope genuinely requires the current weather rather than just leaf status.
struct WeatherDependentReviewGs <: PlantBiophysics.AbstractStomatal_ConductanceModel
    g0::Float64
    g1::Float64
    gs_min::Float64
end
Base.eltype(::WeatherDependentReviewGs) = Float64
PlantSimEngine.inputs_(::WeatherDependentReviewGs) = (
    A=PlantSimEngine.Required(Real), Cₛ=PlantSimEngine.Required(Real))
PlantSimEngine.environment_inputs_(::WeatherDependentReviewGs) = (Rh=0.5,)
PlantBiophysics.gs_closure(m::WeatherDependentReviewGs, status, environment,
    constants=nothing, context=nothing) = m.g1 * environment.Rh / status.Cₛ

@testset "Concrete photosynthesis transport models" begin
    PB = PlantBiophysics
    constants = PlantMeteo.Constants()
    base = Fvcb(VcMaxRef=70.0, JMaxRef=120.0, RdRef=0.6, α=0.32)
    models = (FvcbMarquez(;base), FvcbRectangularMarquez(;base),
        JohnsonBerry(;base,Cb6fMaxRef=90.0),
        JohnsonBerryThermal(;base,Cb6fMaxRef=90.0))
    atmosphere = Atmosphere(T=25.0, Wind=1.0, P=101.3, Rh=0.6,
        Cₐ=400.0, duration=Hour(1))
    function coupled(gas, stomata; light=600.0, Cs=400.0, Tleaf=25.0, meteo=atmosphere)
        scene = CompositeModel(gas, stomata;
            status=Status(aPPFD=light,Tₗ=Tleaf,Cₛ=Cs,Dₗ=1.0), environment=meteo)
        run!(scene)
        return only(model_objects(scene)).status
    end

    @testset "Biochemical hypotheses" begin
        b1 = PB._transport_biochemistry(models[3], 25.0, constants)
        b2 = PB._transport_biochemistry(models[4], 25.0, constants)
        @test PB._transport_assimilation(models[3],600.0,300.0,b1) ≈
            PB._transport_assimilation(models[4],600.0,300.0,b2)
        warm1 = PB._transport_biochemistry(models[3],40.0,constants)
        warm2 = PB._transport_biochemistry(models[4],40.0,constants)
        @test !isapprox(PB._transport_assimilation(models[3],600.0,300.0,warm1),
            PB._transport_assimilation(models[4],600.0,300.0,warm2);rtol=0.01)
        for m in models
            b = PB._transport_biochemistry(m,25.0,constants)
            @test PB._transport_assimilation(m,0.0,400.0,b) ≈ -b.Rd
            @test PB._transport_assimilation(m,600.0,1.0,b) < -b.Rd
        end
    end

    @testset "Zero cuticle and ternary limit" begin
        # Saturated isothermal air makes the ternary term vanish. With zero
        # cuticular conductance and infinite gm, analytical FvCB is recovered.
        saturated = Atmosphere(T=25.0,Wind=1.0,P=101.3,Rh=1.0,
            Cₐ=400.0,duration=Hour(1))
        for stomata in (Medlyn(g0=0.016,g1=2.0), ConstantGs(Gₛ=0.1))
            old = coupled(base,stomata;meteo=saturated)
            fresh = coupled(models[1],CuticularConductance(stomata;gcw=0.0);meteo=saturated)
            @test fresh.A ≈ old.A rtol=1e-8
            @test fresh.Cᵢ ≈ old.Cᵢ rtol=1e-8
            @test fresh.Gₗw ≈ constants.Gsc_to_Gsw*fresh.Gₛ
        end
        @test_throws ArgumentError PB.cuticular_water_conductance(Medlyn(g0=.02,g1=5.5))
        @test_throws ArgumentError coupled(models[1],Medlyn(g0=.02,g1=5.5))
        @test PB.cuticular_water_conductance(CuticularConductance()) == .005
        @test_throws ArgumentError CuticularConductance(gcw=-0.01)
        @test_throws ArgumentError CuticularConductance(co2_ratio=0)
    end

    @testset "Weather-dependent stomatal extensions retain the environment" begin
        stomata=WeatherDependentReviewGs(.016,5.5,.001)
        for m in (base,models...)
            s=coupled(m,CuticularConductance(stomata))
            @test s.Gₛ ≈ max(stomata.gs_min,stomata.g0+stomata.g1*atmosphere.Rh/s.Cₛ*s.A)
            @test s.Gₗw ≈ constants.Gsc_to_Gsw*s.Gₛ+.005
        end
    end

    @testset "Physical roots, respiration and conductance floors" begin
        for m in models, stomata in (Medlyn(g0=.016,g1=2.0),
            Medlyn(g0=-.01,g1=2.0,gs_min=.001), ConstantGs(Gₛ=.08))
            provider = CuticularConductance(stomata)
            for (light,Cs) in ((600.,400.),(0.,400.),(600.,1.))
                s = coupled(m,provider;light,Cs)
                @test all(isfinite,(s.A,s.Cᵢ,s.C꜀,s.Gₛ,s.Gₗw))
                @test s.Cᵢ >= 0 && s.C꜀ >= 0 && s.Gₛ >= 0
                @test s.Gₗw ≈ constants.Gsc_to_Gsw*s.Gₛ+provider.gcw
                b = PB._transport_biochemistry(m,s.Tₗ,constants)
                @test abs(s.A-PB._transport_assimilation(m,light,s.C꜀,b)) < 1e-8
                light == 0 && @test s.A ≈ -b.Rd atol=1e-9
                if Cs == 1 && stomata isa ConstantGs
                    @test s.A < -b.Rd
                end
            end
        end
        finite_gm = coupled(FvcbMarquez(;base,gm=.2),CuticularConductance())
        @test finite_gm.C꜀ ≈ finite_gm.Cᵢ-finite_gm.A/.2
        @test finite_gm.C꜀ < finite_gm.Cᵢ
    end

    @testset "Generic numerical type and root errors" begin
        # A separate linear oracle checks the root solver independently of
        # photosynthetic equations, including an invalid bracket.
        for T in (Float32,Float64)
            function linear_trial(x)
                r = T(3)-T(2)*x
                (residual=r,A=x,Ci=T(300),Cc=T(300),gs=T(.1),Glw=T(.16),expected=x+r)
            end
            root = PB._bisect_transport(linear_trial,T(0),T(4))
            @test root.A isa T
            @test root.A ≈ T(1.5)
            @test abs(root.residual) <= 8eps(T)
            @test_throws DomainError PB._bisect_transport(linear_trial,T(2),T(4))
        end
        @test_throws ArgumentError FvcbMarquez(gm=0)
        @test_throws ArgumentError FvcbRectangularMarquez(base=Fvcb(α=-.1))
        @test_throws ArgumentError JohnsonBerry(Cb6fMaxRef=0)
        @test_throws ArgumentError JohnsonBerry(nL_ref=1.,nC_ref=.1)
        @test_throws ArgumentError JohnsonBerryThermal(Hd_eff=-1)
    end

    @testset "Energy balance receives total epidermal water conductance" begin
        for m in models
            scene = CompositeModel(Monteith(maxiter=200),m,CuticularConductance();
                status=Status(aPPFD=600.,Ra_SW_f=110.,sky_fraction=2.,d=.03),
                environment=atmosphere)
            run!(scene)
            s = only(model_objects(scene)).status
            @test all(isfinite,(s.A,s.Gₗw,s.λE,s.Tₗ))
            @test s.Gₗw ≈ constants.Gsc_to_Gsw*s.Gₛ+.005
            @test abs(s.Rn-s.H-s.λE) < 1e-8
        end
    end
end
