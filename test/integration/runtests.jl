using Test

# This focused integration suite exercises unreleased sibling package branches without
# changing PlantBiophysics' package or test manifests. Override the root when the
# VirtualPlantLab repositories are not checked out next to one another.
dev_root = get(
    ENV,
    "VIRTUALPLANTLAB_DEV_ROOT",
    normpath(joinpath(@__DIR__, "..", "..", "..")),
)

for package in ("ArchimedLight", "PlantGeom", "PlantSimEngine")
    package_path = joinpath(dev_root, package)
    isfile(joinpath(package_path, "Project.toml")) || error(
        "The PlantBiophysics/ArchimedLight integration suite requires the sibling " *
        "package at $package_path. Set VIRTUALPLANTLAB_DEV_ROOT to the directory " *
        "containing the three repositories.",
    )
    package_path in LOAD_PATH || pushfirst!(LOAD_PATH, package_path)
end

using ArchimedLight
using Dates
using GeometryBasics
using PlantBiophysics
using PlantGeom
using PlantMeteo
using PlantSimEngine

include("test-archimedlight-scene-coupling.jl")
