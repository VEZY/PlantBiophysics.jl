const SCHYMANSKI_EVALUATION_REFERENCE = Dict(
    # Recomputed with PlantBiophysics-paper main's environment from the data
    # underlying Schymanski et al. (2017), figure 6a.
    :H => (
        n=14,
        RMSE=32.73056404000107,
        NRMSE=0.22685307744747796,
        Bias=-29.841865518905372,
        NBias=-0.20683172527867139,
        EF=0.4501893280573387,
    ),
    :LE => (
        n=14,
        RMSE=17.569471320757344,
        NRMSE=0.10522975280844017,
        Bias=-6.644727071668484,
        NBias=-0.039797611121350725,
        EF=0.8886228758054245,
    ),
)

@testset "Schymanski et al. (2017) energy flux evaluation" begin
    scenario = run_schymanski_evaluation()
    @test scenario.metadata.n_observations == 14
    for index in eachindex(scenario.simulated.Rn)
        @test isapprox(
            scenario.simulated.Rn[index],
            scenario.simulated.H[index] + scenario.simulated.LE[index];
            rtol=1.0e-12,
        )
    end

    for variable in (:H, :LE)
        metrics = evaluation_metrics(
            getproperty(scenario.observed, variable),
            getproperty(scenario.simulated, variable),
        )
        test_no_regression(
            string(variable),
            metrics,
            SCHYMANSKI_EVALUATION_REFERENCE[variable];
            relative_tolerance=0.05,
            bias_relative_tolerance=0.05,
            ef_tolerance=0.03,
        )
    end
end
