# Scene-light integration

This suite checks the ArchimedLight-to-PlantBiophysics coupling separately from
the package tests. It covers radiation-area conversion, distributed outputs,
dynamic scenes, and heterogeneous physiology models. Scientific assertions and
fixtures live in `test-archimedlight-scene-coupling.jl`.

From the repository root, prepare the dedicated environment and run it:

```sh
julia --project=test/integration -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=test/integration test/integration/runtests.jl
```

To test an ArchimedLight checkout, develop both packages together in the first
command with `Pkg.develop([PackageSpec(path=pwd()), PackageSpec(path="/path/to/ArchimedLight")])`.
PlantGeom and PlantSimEngine otherwise resolve from General. The suite loads
packages from this environment, without changing `LOAD_PATH` or requiring
sibling checkout directories.

For a GitHub run, dispatch the `CI` workflow with `run_scene_integration=true`.
Set `archimedlight_ref` to a branch, tag, or commit; its default is `main`.
This calls `Scene integration` on Julia 1.10 and current Julia, with registered
PlantGeom 0.20.0 and PlantSimEngine 0.15.0. The logs record the candidate commits,
package versions, and loaded paths. Ordinary push and pull-request package tests
remain unchanged.

Set the workflow input `run_benchmarks=true`, or locally set
`PLANTBIOPHYSICS_RUN_SCENE_LIGHT_BENCHMARK=true`, to include the existing timing
and allocation comparison between distributed and manually keyed coupling.
