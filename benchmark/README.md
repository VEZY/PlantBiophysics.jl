# Performance benchmarks

This suite adapts the coupled `Monteith`–`Fvcb`–`Medlyn` workload from
[the PlantBiophysics paper's performance script](https://github.com/VEZY/PlantBiophysics-paper/blob/main/notebooks/performance/Fig5_PlantBiophysics_performance_noPluto.jl)
to PlantSimEngine 0.15's `CompositeModel`, `Object`, and `ModelSpec` API.
It uses deterministic synthetic daylight conditions and explicit physiological
parameters. It measures PlantBiophysics performance; it does not reproduce the
paper's comparisons against R or LeafGasExchange.

## Run the suite locally

In a Julia session started through Kaimon for the `benchmark` directory, first
develop this checkout and instantiate the benchmark environment:

```julia
using Pkg
Pkg.develop(PackageSpec(path=dirname(pwd())))
Pkg.instantiate()
include("benchmarks.jl")
results = run(SUITE)
```

`Pkg.develop` also makes this work on Julia 1.10, which does not use `[sources]`.
Timing results have no pass/fail threshold because they depend on the host.

## Compare revisions with AirspeedVelocity

Install the [AirspeedVelocity CLI](https://github.com/MilesCranmer/AirspeedVelocity.jl#installation)
in a separate tools environment. From this repository, compare the working
tree with a chosen compatible Git revision:

```sh
mkdir -p benchmark/results
benchpkg --path=. --rev=BASELINE,dirty --script=benchmark/benchmarks.jl --add=PlantMeteo@0.9,PlantSimEngine@0.15 --output-dir=benchmark/results --exeflags='--threads=1'
benchpkgtable --path=. --rev=BASELINE,dirty --input-dir=benchmark/results --mode=time,memory --ratio
```

Replace `BASELINE` with a commit, tag, or branch using the PlantSimEngine 0.15
API. The suite intentionally does not support the legacy `ModelList` API.
`--script` freezes this checkout's suite for both revisions. It bypasses
automatic discovery of `benchmark/Project.toml`, so `--add` explicitly supplies
the weather and engine dependencies. After committing the suite, replace
`--script` and `--add` with `--bench-on=SUITE_COMMIT` to freeze both the suite
and its benchmark dependency specification at that commit. AirspeedVelocity
copies `Project.toml` and resolves dependencies for each revision; it does not
copy a manifest.
Use the same Julia version and thread count for comparisons. Do not tune
`evals`: mutating simulations require the suite's `evals=1`.

The **Benchmarks** workflow runs automatically when a pull request is opened,
updated, or reopened, using `pull_request_target` as in PlantSimEngine. It
compares the PR's base and head commits, freezes the suite at the head commit,
and creates or updates a bot comment with time and memory comparisons.
Only the PR comparison job has permission to write PR comments.

## What is measured

| Case | Leaves | Timesteps |
| --- | ---: | ---: |
| `1_leaf_1_step` | 1 | 1 |
| `1_leaf_1000_steps` | 1 | 1000 |
| `1000_leaves_1_step` | 1000 | 1 |
| `100_leaves_100_steps` | 100 | 100 |

Each case has three measurements:

- `construction`: build the objects, independent leaf statuses, and model applications.
- `run`: call `run!` on a fresh scene, including structural compilation, runtime preparation, and simulation.
- `execution`: call `continue!` on a fresh simulation prepared at step zero, excluding construction and runtime preparation.

Weather generation is excluded from every timing. All simulations explicitly
use `outputs=:none`, so output recording and table conversion are excluded.
Each sample gets fresh mutable state and performs exactly one evaluation.
Defaults are 20 samples with a one-second time budget per benchmark, after
Julia's compilation warmup. Reported times and allocations are per entire
case; divide by leaves × timesteps for a per-leaf, per-step value.
