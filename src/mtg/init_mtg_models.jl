"""
    init_mtg_models!(
        mtg::MultiScaleTreeGraph.Node,
        models::Dict{String,<:ModelList},
        i=nothing;
        verbose=true,
        attr_name=:models
    )

initialize the components of an MTG (*i.e.* nodes) with the corresponding models.

The function checks if the models associated to each component of the MTG are fully initialized,
and if not, tries to initialize the variables using the MTG attributes with the exact same name,
and if not found, returns an error.

# Arguments

- `mtg::MultiScaleTreeGraph.Node`: the MTG tree.
- `models::Dict{String,ModelList}`: a dictionary of models named by components names
- `i=nothing`: the time-step to initialize. If `nothing`, initialize all the time-steps.
- `verbose = true`: return information during the processes
- `attr_name = :models`: the node attribute name used to store the models

# Examples

```julia
using PlantBiophysics, MultiScaleTreeGraph, PlantGeom

# Read the file
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","scene","opf","coffee.opf")
mtg = read_opf(file)

# Declare our models:
models = Dict(
    "Leaf" =>
        ModelList(
            energy_balance = Monteith(),
            photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            status = (d = 0.03,)
        )
)

# Checking which variables are needed for our models:
[component => to_initialize(model) for (component, model) in models]
# OK we need to initialize Rₛ, sky_fraction and the PPFD

# We can compute them directly inside the MTG from available variables:
transform!(
    mtg,
    [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y) => :Rₛ,
    :Ra_PAR_f => (x -> x * 4.57) => :PPFD,
    ignore_nothing = true
)

# Initialising all components with their corresponding models and initialisations:
init_mtg_models!(mtg, models)
# Note that this is possible only because the initialisation values are found in the MTG.
# If the initialisations are constant values between components, we can directly initialize
# them in the models definition (we initialize `:d` like this in our example).
```
"""
function init_mtg_models!(
    mtg::MultiScaleTreeGraph.Node,
    models::Dict{String,<:ModelList},
    i=nothing;
    verbose=true,
    attr_name=:models
)

    attr_name_sym = Symbol(attr_name)
    # Check if all components have a model
    component_no_models = setdiff(MultiScaleTreeGraph.components(mtg), keys(models))
    if verbose && length(component_no_models) > 0
        @info string("No model found for component(s) ", join(component_no_models, ", ", ", and "))
    end

    # Get which model has values that needs to be further initialized:
    to_init = Dict()
    for (key, value) in models
        init = to_initialize(value)
        vars = []
        for i in init
            length(i) > 0 && append!(vars, i)
        end
        if length(vars) > 0
            push!(to_init, key => vars)
        end
    end

    # If some values need initialisation, check first if they are found as MTG attributes, and if they do, use them:
    if length(to_init) > 0
        attrs_missing = Dict(key => Set{Symbol}() for key in keys(to_init))
        # node = get_node(mtg, 2070)
        MultiScaleTreeGraph.traverse!(mtg) do node
            # If the component has models associated to it
            # node = get_node(mtg, 816)
            if haskey(models, node.MTG.symbol)
                # If the component needs further initialisations
                if haskey(to_init, node.MTG.symbol)
                    # Search if any is missing:
                    attr_not_found = setdiff(
                        to_init[node.MTG.symbol],
                        collect(keys(node.attributes))
                    )

                    if length(attr_not_found) == 0
                        # If not, initialize the ModelList using attributes
                        @info "Initialising $(to_init[node.MTG.symbol]) using node attributes" maxlog = 1

                        node_model = deepcopy(models[node.MTG.symbol])

                        node[attr_name_sym] =
                            ModelList(
                                node_model.models,
                                init_variables_manual(
                                    node_model.status,
                                    NamedTuple(j => get_attr_i(node, j, i) for j in to_init[node.MTG.symbol])
                                )
                            )
                    else
                        # If some initialisations are not available from the node attributes:
                        for i in attr_not_found
                            push!(attrs_missing[node.MTG.symbol], i)
                        end
                    end
                else
                    # Else we initialize as is
                    node[attr_name_sym] = models[node.MTG.symbol]
                end
            end
        end
        if any([length(value) > 0 for (key, value) in attrs_missing])
            err_msg = [string("\n", key, ": [", join(value, ", ", " and "), "]") for (key, value) in attrs_missing]
            error(
                string(
                    "Some variables need to be initialized for some components before simulation:",
                    join(err_msg, ", ", " and ")
                )
            )
        end
    elseif verbose
        @info string(
            "All models are aleady initialized. Make a new model if you want to update the values."
        )
    end

    return to_init
end

"""
    get_attr_i(node, attr, i<:Nothing)
    get_attr_i(node, attr, i)

Get node attribute at ith value or only value if `i<:Nothing`
"""
function get_attr_i(node, attr, i::T) where {T<:Nothing}
    node[attr]
end

function get_attr_i(node, attr, i)
    node[attr][i]
end

"""
    update_mtg_models!(mtg::MultiScaleTreeGraph.Node, i, attr_name::Symbol)

Update the mtg models initialisations by using the ith time-step. The mtg is considered fully
initialized already once, so [`init_mtg_models!`](@ref) must be called before
`update_mtg_models!`.

The values are updated only for node attributes in `to_init`. Those attributes must have
several time-steps, *i.e.* indexable by 1:n time-steps.
"""
function update_mtg_models!(mtg::MultiScaleTreeGraph.Node, i, to_init, attr_name::Symbol)

    MultiScaleTreeGraph.traverse!(mtg) do node
        # If the component has models associated to it
        if haskey(to_init, node.MTG.symbol)
            # Set the initialisation value of the model at the ith value of the node attribute
            for attr in values(to_init[node.MTG.symbol])
                if length(node[attr]) > 1
                    setproperty!(status(node[attr_name]), attr, node[attr][i])
                    # else
                    #     setproperty!(status(node[attr_name]), attr, node[attr])
                    # NB: no need to update if only one value, it is already set to this value
                end
            end
        end
    end

    return nothing
end
