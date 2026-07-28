const DAILY_EVALUATION_REFERENCE = Dict(
    # Means of the particle-valued metrics rendered by the main-branch notebook
    # for tree 3 on 2001-11-14 (six observations, forced Gs).
    :Dl => (
        n=6,
        RMSE=0.0782593,
        NRMSE=0.0849106,
        Bias=0.0564089,
        NBias=0.061365,
        EF=0.953684,
    ),
    :Tl => (
        n=6,
        RMSE=0.449255,
        NRMSE=0.0466758,
        Bias=0.333377,
        NBias=0.03469,
        EF=0.980114,
    ),
    :A => (
        n=6,
        RMSE=3.15049,
        NRMSE=0.215689,
        Bias=2.29854,
        NBias=0.15742,
        EF=0.682446,
    ),
    :E => (
        n=6,
        RMSE=0.136765,
        NRMSE=0.0417603,
        Bias=0.0838154,
        NBias=0.025665,
        EF=0.982509,
    ),
)

@testset "Medlyn daily forced-Gs evaluation" begin
    scenario = run_daily_evaluation()
    @test scenario.metadata.n_observations == 6
    @test nparticles(first(scenario.simulated.Dl)) == 2000

    for variable in (:Dl, :Tl, :A, :E)
        metrics = evaluation_metrics(
            getproperty(scenario.observed, variable),
            getproperty(scenario.simulated, variable),
        )
        test_no_regression(
            string(variable),
            metrics,
            DAILY_EVALUATION_REFERENCE[variable];
            relative_tolerance=0.10,
            bias_relative_tolerance=0.15,
            ef_tolerance=0.04,
        )
    end
end
