@testset "Historical ARCHIMED adapters stay outside core" begin
    for name in (
        :read_model,
        :is_model,
        :get_process,
        :get_model,
        :instantiate,
        :Translucent,
        :LightIgnore,
        :OpticalProperties,
        :σ,
    )
        @test !isdefined(PlantBiophysics, name)
    end
end

@testset "FvCB net-assimilation spelling" begin
    args = (250.0, 40.0, 42.75, 100.0, 500.0, 1.0, 10.0)
    expected = 40.0 * (250.0 - 42.75) / (250.0 + 2.0 * 42.75) - 1.0

    canonical = Fvcb_net_assimilation(args...)
    @test canonical ≈ expected

    legacy = @test_deprecated r"Fvcb_net_assimiliation.*v0.20" Fvcb_net_assimiliation(args...)
    @test legacy == canonical
end
