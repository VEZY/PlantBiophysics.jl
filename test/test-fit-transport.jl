using Test, DataFrames, PlantBiophysics
using PlantBiophysics.PlantSimEngine

@testset "Conditional gas-exchange fits for transport photosynthesis" begin
    PB = PlantBiophysics
    fit = PlantSimEngine.Evaluation.fit

    # These observations exercise carboxylation, electron transport and
    # respiration (and, with a finite TPU, the high-CO₂/high-light plateau).
    # Use reported Ci directly, as the conditional fitter does.
    function predictions(m, df)
        return [
            PB._transport_assimilation(
                m, row.aPPFD, row.Cᵢ, PB._transport_biochemistry(m, row.Tₗ),
            ) for row in eachrow(df)
        ]
    end

    function synthetic(m; temperatures=(21.0, 25.0, 29.0))
        df = DataFrame([
            (Tₗ=T, aPPFD=light, Cᵢ=Ci)
            for T in temperatures
            for light in (0.0, 160.0, 600.0, 1650.0)
            for Ci in (95.0, 170.0, 250.0, 420.0, 900.0, 1400.0)
        ])
        df.A = predictions(m, df)
        return df
    end

    @testset "Parameter recovery for $Model" for Model in (
        FvcbMarquez, FvcbRectangularMarquez, JohnsonBerry, JohnsonBerryThermal,
    )
        cytochrome = Model in (JohnsonBerry, JohnsonBerryThermal)
        base = Fvcb(Tᵣ=25.0, VcMaxRef=74.0, JMaxRef=180.0, RdRef=1.1, α=0.32)
        truth = cytochrome ? Model(; base, Cb6fMaxRef=140.0) : Model(; base)
        data = synthetic(truth)
        fixed = Fvcb(α=0.32)
        fit_args = cytochrome ? (; Cb6fMaxRef=105.0) : (; JMaxRef=135.0)
        result = fit(Model, data; base=fixed, fit_args...)
        capacity = cytochrome ? :Cb6fMaxRef : :JMaxRef
        @test keys(result) == (:VcMaxRef, capacity, :RdRef, :TPURef, :Tᵣ)
        @test result.VcMaxRef ≈ base.VcMaxRef rtol=1e-4
        @test getproperty(result, capacity) ≈ (cytochrome ? 140.0 : 180.0) rtol=1e-4
        @test result.RdRef ≈ base.RdRef rtol=1e-4
        @test result.TPURef == fixed.TPURef
        @test result.Tᵣ == 25.0
    end

    @testset "Custom thermal parameters and explicit TPU fit" begin
        # Keep the measured temperatures away from the template reference to
        # verify the instance overload does not silently re-center it.
        thermal = (; nL_ref=0.68, nC_ref=0.91, Eₐb=49_000.0, Hd_eff=144_000.0, Δₛ_eff=470.0)
        truth = JohnsonBerryThermal(;
            base=Fvcb(Tᵣ=27.0, VcMaxRef=83.0, RdRef=1.2, TPURef=6.0, α=0.34),
            Cb6fMaxRef=150.0, thermal...,
        )
        template = JohnsonBerryThermal(;
            base=Fvcb(Tᵣ=27.0, VcMaxRef=76.0, RdRef=1.2, TPURef=7.0, α=0.34),
            Cb6fMaxRef=135.0, thermal...,
        )
        data = synthetic(truth; temperatures=(21.0, 28.0, 38.0))
        result = fit(template, data; RdRef_bound=(1.2, 1.2),
            TPURef=7.0, TPURef_bound=(3.0, 12.0))
        @test result.Tᵣ == 27.0
        @test result.RdRef == 1.2
        @test result.VcMaxRef ≈ 83.0 rtol=1e-4
        @test result.Cb6fMaxRef ≈ 150.0 rtol=1e-4
        @test result.TPURef ≈ 6.0 rtol=1e-4
    end

    @testset "Physical bounds reach the optimizer" begin
        m = FvcbMarquez(base=Fvcb(VcMaxRef=74.0, JMaxRef=180.0, RdRef=1.1))
        result = fit(FvcbMarquez, synthetic(m); RdRef=0.6, RdRef_bound=(0.4, 0.7))
        @test result.RdRef ≈ 0.7 atol=1e-5
    end

    @testset "Invalid or uninformative curves" begin
        data = synthetic(FvcbMarquez())
        @test_throws ArgumentError fit(FvcbMarquez, select(data, Not(:Cᵢ)))
        @test_throws ArgumentError fit(FvcbMarquez, data[1:2, :])
        @test_throws ArgumentError fit(FvcbMarquez, data; RdRef_bound=(1.0, 0.0))
        @test_throws ArgumentError fit(FvcbMarquez, data; JMaxRef_bound=(0.0,))
        @test_throws ArgumentError fit(FvcbMarquez(gm=0.25), data)

        bad = copy(data)
        bad.aPPFD[1] = -1.0
        @test_throws ArgumentError fit(FvcbMarquez, bad)
        bad = copy(data)
        bad.A[1] = NaN
        @test_throws ArgumentError fit(FvcbMarquez, bad)

        # Many rows cannot substitute for excitation of the fitted capacities.
        # Dark, high-Ci measurements are insensitive to both Vcmax and Jmax.
        dark = DataFrame(A=fill(-0.8, 12), Cᵢ=fill(400.0, 12),
            Tₗ=fill(25.0, 12), aPPFD=zeros(12))
        @test_throws ArgumentError fit(FvcbMarquez, dark)
    end

    @testset "LI-6800 import to fit" begin
        file = joinpath(pkgdir(PlantBiophysics), "test", "inputs", "data", "6800.csv")
        data = read_licor6800(file)
        # This instrument export is a dynamic CO₂ ramp, not a light or
        # temperature response. Keep Rd fixed at an illustrative prior; do
        # not treat this smoke test as validation of a biological parameter.
        start = JohnsonBerryThermal(;
            base=Fvcb(Tᵣ=30.0, VcMaxRef=60.0, RdRef=0.8, α=0.32),
            Cb6fMaxRef=90.0,
        )
        result = fit(start, data; RdRef_bound=(0.8, 0.8))
        fitted = JohnsonBerryThermal(;
            base=Fvcb(; result.Tᵣ, result.VcMaxRef, result.RdRef, result.TPURef, α=0.32),
            result.Cb6fMaxRef,
        )
        @test result.RdRef == 0.8
        @test all(isfinite, values(result))
        @test sum(abs2, predictions(fitted, data) .- data.A) <
            sum(abs2, predictions(start, data) .- data.A)
    end
end
