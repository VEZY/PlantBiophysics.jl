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
    ModelSpec(Monteith(); name=:energy_balance, on=Many(scale=:Leaf)),
    ModelSpec(Fvcb(); name=:photosynthesis, on=Many(scale=:Leaf)),
    ModelSpec(Medlyn(0.03, 12.0); name=:stomatal_conductance, on=Many(scale=:Leaf)),
)

mtg_root = Node(MultiScaleTreeGraph.NodeMTG("/", "Scene", 1, 0))
mtg_plant = Node(mtg_root, MultiScaleTreeGraph.NodeMTG("+", "Plant", 1, 1))
mtg_sun = Node(mtg_plant, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 1, 2))
mtg_shade = Node(mtg_plant, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 2, 2))

initial_statuses = IdDict(
    mtg_sun => Status(
        Ra_SW_f=20.0,
        sky_fraction=1.0,
        aPPFD=1500.0,
        d=0.03,
    ),
    mtg_shade => Status(
        Ra_SW_f=8.0,
        sky_fraction=0.5,
        aPPFD=600.0,
        d=0.02,
    ),
)

readable_id = node -> Symbol(lowercase(string(symbol(node))), "_", node_id(node))
node_kind = node -> Symbol(symbol(node)) == :Scene ? :scene : :plant

scene = CompositeModel(
    mtg_root;
    id=readable_id,
    kind=node_kind,
    status=node -> get(initial_statuses, node, nothing),
    applications=applications,
    environment=weather,
)

[(
    object_id=object_id(scene, node),
    source_node_id=node_id(source_node(scene, node)),
    aPPFD=model_status(scene, node).aPPFD,
) for node in (mtg_sun, mtg_shade)]

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

Runtime `Status` belongs to the `CompositeModel` registry, never to MTG
attributes. Here `status=` is an explicit import accessor used while the model
registers each MTG node. Compilation may extend an incomplete status with
declared output fields while preserving references to existing fields.

The registry resolves an exact source node, an object identity, or its registered
status without copying state back into the topology:

```@example mtg_simulation
[(
    object_id=object_id(scene, node),
    source_is_exact=source_node(scene, model_status(scene, node)) === node,
    leaf_temperature=model_status(scene, node).Tₗ,
) for node in (mtg_sun, mtg_shade)]
```

For growing MTGs, `add_organ!` creates the node and registers its model object
together. Other topology backends can use `register_object!`,
`remove_object!`, and `reparent_object!`; PlantSimEngine refreshes application
targets before the next timestep.
