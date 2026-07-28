const GLOBAL_EVALUATION_REFERENCE = Dict(
    # Full-precision values behind PlantBiophysics-paper's published statistics.csv.
    # Source: c078fcf9ed8ce56bcb8bcd5703fdc6239cbf8621. The historical
    # timestamp-only join duplicated rows; these remain directional quality
    # references, while this test evaluates the 536 observations exactly once.
    :A => (
        n=536,
        RMSE=2.193346293839416,
        NRMSE=0.046160440321971974,
        Bias=0.9206779409007164,
        NBias=0.019376283291914636,
        EF=0.9574195211264226,
    ),
    :E => (
        n=536,
        RMSE=0.5031344032292382,
        NRMSE=0.057106913340726075,
        Bias=0.30086976421240447,
        NBias=0.034149411054870994,
        EF=0.8929128056592378,
    ),
    :Gs => (
        n=536,
        RMSE=0.024804460212580308,
        NRMSE=0.069181842195802,
        Bias=0.009147773563370407,
        NBias=0.025513952800434156,
        EF=0.8645239281489471,
    ),
    :Tl => (
        n=536,
        RMSE=0.505460884607007,
        NRMSE=0.02376722102127635,
        Bias=0.3261429284077967,
        NBias=0.015335530997658046,
        EF=0.9873151953045115,
    ),
)

@testset "Medlyn global A/E/Gs/Tl evaluation" begin
    scenario = run_global_evaluation()
    @test scenario.metadata.n_observations == 673
    @test scenario.metadata.n_parameters == 46
    @test scenario.metadata.parameter_curves_unique
    @test scenario.metadata.curves_match
    @test scenario.metadata.n_evaluated == 536

    for variable in (:A, :E, :Gs, :Tl)
        metrics = evaluation_metrics(
            getproperty(scenario.observed, variable),
            getproperty(scenario.simulated, variable),
        )
        test_no_regression(
            string(variable),
            metrics,
            GLOBAL_EVALUATION_REFERENCE[variable];
            relative_tolerance=0.05,
            bias_relative_tolerance=0.10,
            ef_tolerance=0.02,
        )
    end
end
