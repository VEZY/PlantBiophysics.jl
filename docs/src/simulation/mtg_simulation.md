# Whole-Plant Simulation From An MTG

PlantBiophysics does not prescribe plant topology. A
`MultiScaleTreeGraph` (MTG) can provide the hierarchy and node metadata, while
PlantSimEngine supplies the same objects, compiler, applications, environment,
and output retention used in the [several-object tutorial](several_objects_simulation.md).

This complete example constructs a small in-memory MTG with one plant and two
leaves, then runs the coupled leaf model over three weather timesteps.

```@example mtg_simulation
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates, DataFrames
using MultiScaleTreeGraph

weather = Weather([
    Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, duration=Hour(1)),
    Atmosphere(T=23.0, Wind=1.5, P=101.3, Rh=0.60, duration=Hour(1)),
    Atmosphere(T=25.0, Wind=2.0, P=101.3, Rh=0.55, duration=Hour(1)),
])

applications = (
    ModelSpec(Monteith(); name=:energy_balance) |>
        AppliesTo(Many(scale=:Leaf)),
    ModelSpec(Fvcb(); name=:photosynthesis) |>
        AppliesTo(Many(scale=:Leaf)),
    ModelSpec(Medlyn(0.03, 12.0); name=:stomatal_conductance) |>
        AppliesTo(Many(scale=:Leaf)),
)

mtg_root = Node(MultiScaleTreeGraph.NodeMTG("/", "Scene", 1, 0))
mtg_plant = Node(mtg_root, MultiScaleTreeGraph.NodeMTG("+", "Plant", 1, 1))
mtg_sun = Node(mtg_plant, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 1, 2))
mtg_shade = Node(mtg_plant, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 2, 2))

mtg_sun[:plantsimengine_status] = Status(
    Ra_SW_f=20.0,
    sky_fraction=1.0,
    aPPFD=1500.0,
    d=0.03,
)
mtg_shade[:plantsimengine_status] = Status(
    Ra_SW_f=8.0,
    sky_fraction=0.5,
    aPPFD=600.0,
    d=0.02,
)

readable_id = node -> Symbol(lowercase(string(symbol(node))), "_", node_id(node))
node_kind = node -> Symbol(symbol(node)) == :Scene ? :scene : :plant

scene = CompositeModel(
    mtg_root;
    id=readable_id,
    kind=node_kind,
    applications=applications,
    environment=weather,
)

simulation = run!(
    scene;
    steps=length(weather),
    outputs=OutputRequest(
        Many(scale=:Leaf),
        :Tₗ;
        name=:leaf_temperature,
        application=:energy_balance,
    ),
)

DataFrame(collect_outputs(
    simulation,
    :leaf_temperature;
    sink=nothing,
))
```

If an MTG node has a `:plantsimengine_status` attribute, the adapter uses it as
the node's initial state. Compilation may extend an incomplete status with
declared output fields while preserving references to existing fields. The
live compiled state is therefore inspected through `model_objects(scene)`.

Use the same accessors when inspecting the adapter separately:

```@example mtg_simulation
adapted_objects = objects_from_mtg(
    mtg_root;
    id=readable_id,
    kind=node_kind,
)
[(object.id, object.scale, object.kind) for object in adapted_objects]
```

For growing MTGs, `add_organ!` creates the node and registers its model object
together. Other topology backends can use `register_object!`,
`remove_object!`, and `reparent_object!`; PlantSimEngine refreshes application
targets before the next timestep.
