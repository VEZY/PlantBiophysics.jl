module WaterConductanceInterfaceTests

using Test, Dates
using PlantBiophysics, PlantMeteo, PlantSimEngine

leaf_status(scene) = only(model_objects(scene)).status

@testset "Explicit leaf water-conductance interface" begin
    @testset "Stomatal providers publish both gases" begin
        environment = Atmosphere(T=25.0, Wind=1.0, P=101.3, Rh=0.6,
            Cₐ=400.0, duration=Minute(1))

        for T in (Float32, Float64)
            constants = Constants{T}(Gsc_to_Gsw=T(1.75))
            models = (
                Medlyn(T(0.03), T(2.0), T(0.001)),
                Tuzet(T(0.03), T(2.0), T(-1.5), T(2.0), T(30), T(0.001)),
                ConstantGs(T(0), T(0.1)),
            )
            for model in models
                @test (:Gₛ, :Gₗw) ⊆ keys(PlantSimEngine.outputs_(model))
                contracts = PlantSimEngine.variable_contracts(model)
                @test contracts.Gₛ == PlantBiophysics.STOMATAL_CO2_CONDUCTANCE_CONTRACT
                @test contracts.Gₗw == PlantBiophysics.LEAF_WATER_CONDUCTANCE_CONTRACT

                status = Status(A=T(12), Cₛ=T(400), Dₗ=T(1), Ψₗ=T(-1),
                    Gₛ=T(-Inf), Gₗw=T(-Inf))
                PlantSimEngine.run!(model, status, environment, constants, nothing)
                @test isfinite(status.Gₛ) && status.Gₛ > 0
                @test status.Gₗw ≈ T(1.75) * status.Gₛ
                @test typeof(status.Gₗw) == typeof(status.Gₛ)
            end
        end
    end

    @testset "Photosynthesis forwards accepted water conductance" begin
        environment = Atmosphere(T=25.0, Wind=1.0, P=101.3, Rh=0.6,
            Cₐ=400.0, duration=Minute(1))
        constants = Constants(Gsc_to_Gsw=1.75)
        for model in (Fvcb(), FvcbIter(), ConstantAGs(10.0))
            @test :Gₗw in keys(PlantSimEngine.outputs_(model))
            @test PlantSimEngine.variable_contracts(model).Gₗw ==
                PlantBiophysics.LEAF_WATER_CONDUCTANCE_CONTRACT
            scene = CompositeModel(model, ConstantGs(Gₛ=0.2);
                status=Status(aPPFD=600.0, Tₗ=25.0, Cₛ=400.0,
                    Dₗ=1.0, Gbc=0.7), environment=environment)
            run!(scene; constants=constants)
            status = leaf_status(scene)
            @test isfinite(status.A)
            @test status.Gₛ == 0.2
            @test status.Gₗw ≈ 0.35
        end
    end

    @testset "Monteith publishes the accepted trial and preserves legacy results" begin
        environment = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65,
            duration=Hour(1))
        scene = CompositeModel(Monteith(), Fvcb(α=0.24), Medlyn(0.03, 12.0);
            status=Status(Ra_SW_f=13.747, sky_fraction=1.0,
                aPPFD=1500.0, d=0.03), environment=environment)
        run!(scene)
        status = leaf_status(scene)
        @test status.Gₗw ≈ Constants().Gsc_to_Gsw * status.Gₛ
        # The existing test-energy_balance reference uses this same scene.
        @test status.A ≈ 29.353021159302116
        @test status.Tₗ ≈ 17.659815647954556
        @test status.λE ≈ 142.76430753585024
        @test status.Rn ≈ status.H + status.λE
        @test PlantSimEngine.variable_contracts(Monteith()).Gₗw ==
            PlantBiophysics.LEAF_WATER_CONDUCTANCE_CONTRACT
    end

    @testset "Energy-only simulations prescribe water conductance explicitly" begin
        environment = Atmosphere(T=25.0, Wind=1.0, P=101.3, Rh=0.6,
            Cₐ=400.0, duration=Minute(1))

        # ConstantA remains an assimilation-only model when used alone.
        standalone = CompositeModel(ConstantA(0.0); environment=environment)
        run!(standalone)
        @test leaf_status(standalone).A == 0.0
        @test :Gₗw ∉ keys(PlantSimEngine.inputs_(ConstantA()))

        energy = CompositeModel(Monteith(maxiter=100), ConstantA(0.0);
            status=Status(Ra_SW_f=110.0, sky_fraction=2.0, d=0.03,
                Gₗw=0.15), environment=environment)
        run!(energy)
        status = leaf_status(energy)
        @test status.Gₗw == 0.15
        @test isfinite(status.λE)
        @test status.Rn ≈ status.H + status.λE

        # An old CO₂-only status must no longer silently trigger conversion.
        missing_water = CompositeModel(Monteith(), ConstantA(0.0);
            status=Status(Ra_SW_f=110.0, sky_fraction=2.0, d=0.03,
                Gₛ=0.15), environment=environment)
        @test_throws DomainError run!(missing_water)
    end
end

end # module
