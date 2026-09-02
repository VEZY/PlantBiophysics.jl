# Generate all methods for the photosynthesis process: several meteo time-steps, components,
#  over an MTG, and the mutating /non-mutating versions
@process "photosynthesis" """
Photosynthesis process to compute the CO₂ assimilation, and potentially
hard-coupled with a stomatal conductance process.

The models used are selected as scene applications. For example, use `Fvcb`
for photosynthesis and `Medlyn` for its stomatal-conductance hard dependency.

# Examples

```julia
using PlantSimEngine, PlantMeteo, PlantBiophysics

meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

scene = leaf_scene(
    Fvcb(),
    Medlyn(0.03, 12.0);
    status=Status(Tₗ=25.0, aPPFD=1000.0, Cₛ=400.0, Dₗ=meteo.VPD),
    environment=meteo,
)
run!(scene)
only(model_objects(scene; scale=:Leaf)).status.A
```

Note that we use `VPD` as an approximation of `Dₗ` here because we don't have the leaf temperature (*i.e.* `Dₗ = VPD` when `Tₗ = T`).
""" verbose = false

# Default policy for assimilation rates when consumed at coarser clocks.
# An explicit policy on a scene `ModelSpec(...; inputs=...)` selector overrides this default.
PlantSimEngine.output_policy(::Type{<:AbstractPhotosynthesisModel}) = (A=PlantSimEngine.Integrate(PlantMeteo.DurationSumReducer()),)
