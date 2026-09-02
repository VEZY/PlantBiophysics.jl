@testset "Fitting FvCB" begin
    file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "data", "P1F20129.csv")
    df = read_walz(file)
    # Removing the Rh and light curves for the fitting because temperature varies
    filter!(x -> x.curve != "Rh Curve" && x.curve != "ligth Curve", df)

    # Fit the parameter values:
    VcMaxRef, JMaxRef, RdRef, TPURef = PlantSimEngine.Evaluation.fit(Fvcb, df; Tᵣ=25.0)
    # Note that Tᵣ was set to 25 °C in our response curve. You should adapt its value to what you
    # had during the response curves

    @test VcMaxRef ≈ 46.247 atol = 1e-2
    @test JMaxRef ≈ 80.368 atol = 1e-2
    @test RdRef ≈ 0.499 atol = 1e-2
    @test TPURef ≈ 5.596 atol = 1e-2


    VcMaxRef, JMaxRef, RdRef, TPURef = PlantSimEngine.Evaluation.fit(Fvcb, df; Tᵣ=25.0, Eₐᵥ=71100.0)

    @test VcMaxRef ≈ 45.204 atol = 1e-2
    @test JMaxRef ≈ 80.386 atol = 1e-2
    @test RdRef ≈ 0.503 atol = 1e-2
    @test TPURef ≈ 5.598 atol = 1e-2
end

@testset "Fitting Medlyn" begin
    file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "data", "P1F20129.csv")
    df = read_walz(file)
    # Removing the CO2 and ligth Curve, we fit the parameters on the Rh curve:
    filter!(x -> x.curve != "ligth Curve" && x.curve != "CO2 Curve", df)


    # Fit the parameter values:
    g0, g1 = PlantSimEngine.Evaluation.fit(Medlyn, df)

    @test g0 ≈ 0.02644 atol = 1e-4
    @test g1 ≈ 0.131696 atol = 1e-4
end

@testset "Fitting Beer" begin
    constants = PlantMeteo.Constants()
    lai = [1.0, 2.0, 3.0]
    incident_par = [200.0, 300.0, 400.0]
    expected_k = -log1p(-0.6) / 2.0
    expected_f_abs = @. 1.0 - exp(-expected_k * lai)
    observations = DataFrame(
        LAI=lai,
        Ri_PAR_f=incident_par,
        aPPFD=incident_par .* constants.J_to_umol .* expected_f_abs,
    )

    fitted = PlantSimEngine.Evaluation.fit(Beer, observations)
    reconstructed_f_abs = @. 1.0 - exp(-fitted.k * lai)

    @test expected_f_abs[2] ≈ 0.6
    @test fitted.k ≈ expected_k
    @test reconstructed_f_abs ≈ expected_f_abs

    observation(lai, f_abs; incident=300.0) = DataFrame(
        LAI=[lai],
        Ri_PAR_f=[incident],
        aPPFD=[incident * constants.J_to_umol * f_abs],
    )
    @test PlantSimEngine.Evaluation.fit(Beer, observation(2.0, 0.0)).k == 0.0

    tiny = observation(2.0, eps(Float64) / 2.0)
    tiny_f_abs = tiny.aPPFD[1] / (tiny.Ri_PAR_f[1] * constants.J_to_umol)
    tiny_k = PlantSimEngine.Evaluation.fit(Beer, tiny).k
    @test tiny_k > 0.0
    @test tiny_k ≈ -log1p(-tiny_f_abs) / tiny.LAI[1]

    @test_throws ArgumentError PlantSimEngine.Evaluation.fit(
        Beer,
        DataFrame(LAI=Float64[], Ri_PAR_f=Float64[], aPPFD=Float64[]),
    )

    for invalid_lai in (0.0, -1.0, Inf, NaN)
        @test_throws DomainError PlantSimEngine.Evaluation.fit(
            Beer,
            observation(invalid_lai, 0.6),
        )
    end
    for invalid_f_abs in (-0.1, 1.0, 1.1, Inf, NaN)
        @test_throws DomainError PlantSimEngine.Evaluation.fit(
            Beer,
            observation(2.0, invalid_f_abs),
        )
    end
    for invalid_incident in (0.0, -1.0, Inf, -Inf, NaN)
        @test_throws DomainError PlantSimEngine.Evaluation.fit(
            Beer,
            observation(2.0, 0.6; incident=invalid_incident),
        )
    end
    for invalid_J_to_umol in (0.0, -1.0, Inf, -Inf, NaN)
        @test_throws DomainError PlantSimEngine.Evaluation.fit(
            Beer,
            observation(2.0, 0.6);
            J_to_umol=invalid_J_to_umol,
        )
    end

    negative_J_error = try
        PlantSimEngine.Evaluation.fit(
            Beer,
            DataFrame(
                LAI=[2.0],
                Ri_PAR_f=[300.0],
                aPPFD=[-300.0 * constants.J_to_umol * 0.6],
            );
            J_to_umol=-constants.J_to_umol,
        )
        nothing
    catch error
        error
    end
    @test negative_J_error isa DomainError
    @test negative_J_error.val == -constants.J_to_umol
    @test occursin("J_to_umol", sprint(showerror, negative_J_error))

    overflow_error = try
        PlantSimEngine.Evaluation.fit(
            Beer,
            DataFrame(LAI=[2.0], Ri_PAR_f=[floatmax(Float64)], aPPFD=[0.0]),
        )
        nothing
    catch error
        error
    end
    @test overflow_error isa DomainError
    @test overflow_error.val == Inf
    @test occursin("incident PAR", sprint(showerror, overflow_error))

    double_negative = DataFrame(
        LAI=[2.0],
        Ri_PAR_f=[-300.0],
        aPPFD=[300.0 * constants.J_to_umol * 0.6],
    )
    @test_throws DomainError PlantSimEngine.Evaluation.fit(
        Beer,
        double_negative;
        J_to_umol=-constants.J_to_umol,
    )
end
