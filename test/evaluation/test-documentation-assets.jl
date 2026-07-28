@testset "Evaluation documentation figures" begin
    asset_dir = normpath(
        joinpath(@__DIR__, "..", "..", "docs", "src", "assets", "evaluation"),
    )
    for filename in (
        "medlyn_global.svg",
        "medlyn_daily.svg",
        "schymanski_energy_fluxes.svg",
    )
        figure = joinpath(asset_dir, filename)
        @test isfile(figure)
        @test filesize(figure) > 1_000
    end
end

@testset "Documentation logo source and asset" begin
    asset_dir = normpath(
        joinpath(@__DIR__, "..", "..", "docs", "src", "assets"),
    )
    source = joinpath(asset_dir, "logo.jl")
    figure = joinpath(asset_dir, "logo.svg")

    @test isfile(source)
    @test occursin("function generate_logo", read(source, String))
    @test isfile(figure)
    @test filesize(figure) > 1_000
end
