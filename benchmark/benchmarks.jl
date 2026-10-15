using BenchmarkTools
using Dates
using PlantBiophysics
using PlantMeteo
using PlantSimEngine

# Adapted from the coupled-leaf and scaling workloads in PlantBiophysics-paper,
# notebooks/performance/Fig5_PlantBiophysics_performance_noPluto.jl.
# Keep this file self-contained: AirspeedVelocity freezes it across revisions.
const SUITE = BenchmarkGroup()
const BENCHMARK_CASES = (
    (name="1_leaf_1_step", leaves=1, steps=1),
    (name="1_leaf_1000_steps", leaves=1, steps=1000),
    (name="1000_leaves_1_step", leaves=1000, steps=1),
    (name="100_leaves_100_steps", leaves=100, steps=100),
)
const BENCHMARK_CONSTANTS = Constants()

function benchmark_weather(nsteps)
    # Deterministic, mild daylight conditions; no input generation is timed.
    return Weather([
        Atmosphere(
            date=DateTime(2000, 1, 1) + Hour(step - 1),
            T=22.0 + mod(step - 1, 6),
            Wind=1.0,
            P=101.325,
            Rh=0.6,
            Cₐ=400.0,
            duration=Hour(1),
        ) for step in 1:nsteps
    ])
end

function benchmark_status(index)
    # Absorbed shortwave: W m⁻²; absorbed PAR: µmol m⁻² s⁻¹; d: m.
    # PAR energy stays below total absorbed shortwave for every leaf.
    illumination = 0.6 + 0.1 * mod(index - 1, 5)
    return Status(
        Ra_SW_f=350.0 * illumination,
        aPPFD=1000.0 * illumination,
        sky_fraction=0.8,
        d=0.03,
    )
end

function benchmark_scene(nleaves, weather)
    photosynthesis = Fvcb(VcMaxRef=80.0, JMaxRef=150.0, RdRef=1.0, TPURef=10.0)
    stomatal_conductance = Medlyn(0.03, 5.8)
    return CompositeModel(
        (Object(Symbol(:leaf_, index); scale=:Leaf, status=benchmark_status(index))
         for index in 1:nleaves)...;
        applications=(
            ModelSpec(Monteith(); on=Many(scale=:Leaf)),
            ModelSpec(photosynthesis; on=Many(scale=:Leaf)),
            ModelSpec(stomatal_conductance; on=Many(scale=:Leaf)),
        ),
        environment=weather,
    )
end

for phase in ("construction", "run", "execution")
    SUITE[phase] = BenchmarkGroup()
end

for case in BENCHMARK_CASES
    weather = benchmark_weather(case.steps)
    nleaves, nsteps = case.leaves, case.steps

    SUITE["construction"][case.name] = @benchmarkable benchmark_scene(
        $nleaves, $weather,
    ) evals = 1 samples = 20 seconds = 1

    # Fresh scene per sample: includes structural compilation, runtime setup,
    # and simulation, but excludes scene construction and weather generation.
    SUITE["run"][case.name] = @benchmarkable run!(
        scene; steps=$nsteps, constants=$BENCHMARK_CONSTANTS, outputs=:none,
    ) setup = (scene = benchmark_scene($nleaves, $weather)) evals = 1 samples = 20 seconds = 1

    # Prepare a new runtime at step zero per sample. Only execution is timed;
    # each sample starts from identical state and cannot exhaust the weather.
    SUITE["execution"][case.name] = @benchmarkable continue!(
        simulation; steps=$nsteps,
    ) setup = (
        scene = benchmark_scene($nleaves, $weather);
        simulation = run!(scene; steps=0, constants=$BENCHMARK_CONSTANTS, outputs=:none)
    ) evals = 1 samples = 20 seconds = 1
end
