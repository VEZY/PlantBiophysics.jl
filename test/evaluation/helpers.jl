central_metric(value::AbstractParticles) = pmean(value)
central_metric(value) = value

function evaluation_metrics(observed, simulated)
    @assert length(observed) == length(simulated)
    residuals = simulated .- observed
    rmse = sqrt(sum(abs2, residuals) / length(observed))
    observed_range = maximum(observed) - minimum(observed)
    bias = mean(residuals)
    ef = 1 - sum(abs2, residuals) / sum(abs2, observed .- mean(observed))

    return (
        n=length(observed),
        RMSE=central_metric(rmse),
        NRMSE=central_metric(rmse / observed_range),
        Bias=central_metric(bias),
        NBias=central_metric(bias / observed_range),
        EF=central_metric(ef),
    )
end

function test_no_regression(
    label,
    current,
    reference;
    relative_tolerance,
    bias_relative_tolerance=relative_tolerance,
    ef_tolerance,
    absolute_tolerance=1.0e-10,
)
    @testset "$label" begin
        @test current.n == reference.n
        @test all(
            isfinite,
            (current.RMSE, current.NRMSE, current.Bias, current.NBias, current.EF),
        )

        @test current.RMSE <=
              reference.RMSE * (1 + relative_tolerance) + absolute_tolerance
        @test current.NRMSE <=
              reference.NRMSE * (1 + relative_tolerance) + absolute_tolerance
        @test abs(current.Bias) <=
              abs(reference.Bias) * (1 + bias_relative_tolerance) + absolute_tolerance
        @test abs(current.NBias) <=
              abs(reference.NBias) * (1 + bias_relative_tolerance) + absolute_tolerance
        @test current.EF >= reference.EF - ef_tolerance
    end
end
