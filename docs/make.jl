using PlantBiophysics
using Documenter

makedocs(;
    modules=[PlantBiophysics],
    authors="remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo="https://github.com/VEZY/PlantBiophysics.jl/blob/{commit}{path}#L{line}",
    sitename="PlantBiophysics.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://VEZY.github.io/PlantBiophysics.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/VEZY/PlantBiophysics.jl",
)
