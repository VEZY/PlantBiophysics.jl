@testset "mtg: init_mtg_models!" begin
    file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "data", "P1F20129.csv")
    df = read_walz(file)
    # Removing the Rh and light curves for the fitting because temperature varies
    filter!(x -> x.curve != "Rh Curve" && x.curve != "ligth Curve", df)

    # Fit the parameter values:
    VcMaxRef, JMaxRef, RdRef, TPURef = fit(Fvcb, df; Tᵣ = 25.0)
    # Note that Tᵣ was set to 25 °C in our response curve. You should adapt its value to what you
    # had during the response curves

    @test VcMaxRef ≈ 46.247 atol = 1e-2
    @test JMaxRef ≈ 82.966 atol = 1e-2
    @test RdRef ≈ 0.499 atol = 1e-2
    @test TPURef ≈ 5.596 atol = 1e-2
end
