@testset "Fitting FvCB" begin
    file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "data", "P1F20129.csv")
    df = read_walz(file)
    # Removing the Rh and light curves for the fitting because temperature varies
    filter!(x -> x.curve != "Rh Curve" && x.curve != "ligth Curve", df)

    # Fit the parameter values:
    VcMaxRef, JMaxRef, RdRef, TPURef = fit(Fvcb, df; Tᵣ=25.0)
    # Note that Tᵣ was set to 25 °C in our response curve. You should adapt its value to what you
    # had during the response curves

    @test VcMaxRef ≈ 46.247 atol = 1e-2
    @test JMaxRef ≈ 82.966 atol = 1e-2
    @test RdRef ≈ 0.499 atol = 1e-2
    @test TPURef ≈ 5.596 atol = 1e-2
end


@testset "Fitting Medlyn" begin
    file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "data", "P1F20129.csv")
    df = read_walz(file)
    # Removing the CO2 and ligth Curve, we fit the parameters on the Rh curve:
    filter!(x -> x.curve != "ligth Curve" && x.curve != "CO2 Curve", df)


    # Fit the parameter values:
    g0, g1 = fit(Medlyn, df)

    @test g0 ≈ 0.02644 atol = 1e-4
    @test g1 ≈ 0.13101 atol = 1e-4
end
