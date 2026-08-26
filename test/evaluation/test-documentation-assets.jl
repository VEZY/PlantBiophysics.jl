@testset "Evaluation documentation figures" begin
    docs_src = normpath(joinpath(@__DIR__, "..", "..", "docs", "src"))
    asset_dir = normpath(
        joinpath(docs_src, "assets", "evaluation"),
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

    schymanski_source = joinpath(docs_src, "models", "schymanski.jl")
    @test isfile(schymanski_source)
    @test occursin(
        "EvaluationFigures.generate_schymanski_figure()",
        read(schymanski_source, String),
    )

    simulation_dir = joinpath(docs_src, "simulation")
    restored_tutorials = (
        "several_simulation.md" => "step!(simulation)",
        "several_objects_simulation.md" => "CompositeModel(",
        "mtg_simulation.md" => "source_node(scene, model_status(scene, node))",
    )
    for (filename, marker) in restored_tutorials
        tutorial = joinpath(simulation_dir, filename)
        @test isfile(tutorial)
        @test occursin(marker, read(tutorial, String))
    end
    mtg_tutorial = read(joinpath(simulation_dir, "mtg_simulation.md"), String)
    @test !occursin("plantsimengine_status", mtg_tutorial)
end

@testset "Documentation logo source and asset" begin
    docs_dir = normpath(joinpath(@__DIR__, "..", "..", "docs"))
    asset_dir = normpath(
        joinpath(docs_dir, "src", "assets"),
    )
    source = joinpath(asset_dir, "logo.jl")
    figure = joinpath(asset_dir, "logo.png")
    make_source = replace(
        read(joinpath(docs_dir, "make.jl"), String),
        "\r\n" => "\n",
    )

    @test isfile(source)
    logo_source = read(source, String)
    @test occursin("function generate_logo", logo_source)
    @test occursin(
        "DEFAULT_OUTPUT = joinpath(@__DIR__, \"logo.png\")",
        logo_source,
    )
    @test occursin("PlantBiophysicsLogo.generate_logo()", make_source)
    @test occursin("EvaluationFigures.generate_evaluation_figures()", make_source)
    @test isfile(figure)
    @test filesize(figure) > 10_000

    header = read(figure, 26)
    @test header[1:8] == UInt8[
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
    ]
    @test header[13:16] == collect(codeunits("IHDR"))
    uint32_be(bytes) = Int(foldl(
        (value, byte) -> (value << 8) | UInt32(byte),
        bytes;
        init=UInt32(0),
    ))
    width = uint32_be(header[17:20])
    height = uint32_be(header[21:24])
    @test width == height
    # Documenter caps the logo at 6rem (96 CSS pixels); 384 pixels keeps it
    # sharp up to a 4× device-pixel ratio.
    @test width >= 384
    @test header[26] == 0x06 # RGBA, so the transparent background is preserved.
    @test !isfile(joinpath(asset_dir, "logo.svg"))
end

@testset "Standard development dependency workflow" begin
    repository = normpath(joinpath(@__DIR__, "..", ".."))
    for file in (
        "Project.toml",
        joinpath("test", "Project.toml"),
        joinpath("docs", "Project.toml"),
    )
        project_source = read(joinpath(repository, file), String)
        @test !occursin("/Users/", project_source)
        @test !occursin(r"path\s*=\s*\"/", project_source)
    end

    ci_workflow = read(
        joinpath(repository, ".github", "workflows", "ci.yml"),
        String,
    )
    @test occursin("repository: VirtualPlantLab/PlantSimEngine.jl", ci_workflow)
    @test occursin("ref: multi-plants", ci_workflow)
    @test occursin(
        "Pkg.develop(PackageSpec(path=\"PlantSimEngine\"))",
        ci_workflow,
    )
    @test occursin("julia-actions/julia-buildpkg@latest", ci_workflow)
    @test occursin("julia-actions/julia-runtest@latest", ci_workflow)
    @test !occursin("scripts/instantiate.jl", ci_workflow)

    docs_workflow = read(
        joinpath(repository, ".github", "workflows", "docs.yml"),
        String,
    )
    @test occursin("version: \"1\"", docs_workflow)
    @test occursin(
        "Pkg.develop(PackageSpec(path=\"PlantSimEngine\"))",
        docs_workflow,
    )
    @test occursin("repository: VirtualPlantLab/PlantSimEngine.jl", docs_workflow)
    @test occursin("ref: multi-plants", docs_workflow)
    @test !occursin("docs/instantiate.jl", docs_workflow)
    @test occursin(
        "PlantBiophysics = {path = \"..\"}",
        read(joinpath(repository, "docs", "Project.toml"), String),
    )

    for file in (
        joinpath("scripts", "instantiate.jl"),
        joinpath("scripts", "pinned_dependencies.jl"),
        joinpath("docs", "instantiate.jl"),
        joinpath("docs", "figures", "instantiate.jl"),
        joinpath("docs", "figures", "Project.toml"),
    )
        @test !isfile(joinpath(repository, file))
    end
end
