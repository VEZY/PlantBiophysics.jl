# Generate all methods for the photosynthesis process: several meteo time-steps, components,
#  over an MTG, and the mutating /non-mutating versions
@process "photosynthesis" """
Photosynthesis process to compute the CO₂ assimilation, and potentially
hard-coupled with a stomatal conductance process.

The models used are defined by the types of the `photosynthesis` and `stomatal_conductance`
fields of the `ModelList`. For exemple to use the implementation of the Farquhar–von Caemmerer–Berry
(FvCB) model, use the type `Fvcb` (see example below).

# Examples

```julia
using PlantSimEngine, PlantMeteo, PlantBiophysics

meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

# Using Fvcb model:
leaf =
    ModelList(
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        status = (Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = meteo.VPD)
    )

run!(leaf, meteo)

# ---Using several components---

leaf2 = copy(leaf)
leaf2.status.PPFD = 800.0

run!([leaf,leaf2],meteo)

# ---Using several meteo time-steps---

w = Weather(
        [
            Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
            Atmosphere(T = 25.0, Wind = 1.5, P = 101.3, Rh = 0.55)
        ],
        (site = "Test site,)
    )

run!(leaf, w)

# ---Using several meteo time-steps and several components---

run!(Dict(:leaf1 => leaf, :leaf2 => leaf2), w)

# Using a model file:

model = read_model("a-model-file.yml")

# Initialising the mandatory variables:
init_status!(model, Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = meteo.VPD)

# Running a simulation for all component types in the same scene:
run!(model, meteo)
model["Leaf"].status.A

```
"""
