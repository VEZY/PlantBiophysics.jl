"""
    init_mtg_models!(mtg, models::Dict{String,<:AbstractModel})

Initialise the components of an MTG (*i.e.* nodes) with the corresponding models.

The function checks if the models associated to each component of the MTG are fully initialized,
and if not, it tries to initialise the variables using the MTG attributes of the same name,
and if not found, returns an error.

```julia
# Read the file
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","scene","opf","coffee.opf")
mtg = read_opf(file)

# Declare our models:
models = Dict(
    "Leaf" =>
        LeafModels(
            energy = Monteith(),
            photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            d = 0.03
        )
)

# Checking which variables are needed for our models:
[component => to_initialise(model) for (component, model) in models]
# OK we need to initialise Rₛ, skyFraction and the PPFD

# We can compute them directly inside the MTG from available variables:
transform!(
    mtg,
    [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y) => :Rₛ,
    :Ra_PAR_f => (x -> x * 4.57) => :PPFD,
    ignore_nothing = true
)

# Initialising all components with their corresponding models and initialisations:
init_mtg_models!(mtg, models)
# Note that this is possible only because the initialisations values are found in the MTG.
# If the initialisations are constant values between components, we can directly initilise
# them in the models definition (we initialise d like this).
```
"""
function init_mtg_models!(mtg, models::Dict{String,<:AbstractModel}; verbose = true)

    # Check if all components have a model
    component_no_models = setdiff(components(mtg), keys(models))
    if verbose && length(component_no_models) > 0
        @info string("No model found for component(s) ", join(component_no_models, ", ", ", and "))
    end

    # Get which model has values that needs to be further initialised:

    to_init = Dict()
    for (key, value) in models
        init = to_initialise(value)
        if length(init) > 0
            push!(to_init, key => init)
        end
    end

    # If some values need initialisation, check first if they are found as MTG attributes, and if they do, use them:
    if length(to_init) > 0
        attrs_missing = Dict(i => Set{Symbol}() for i in keys(to_init))
        # node = get_node(mtg, 2070)
        traverse!(mtg) do node
            # If the component has models associated to it
            if haskey(models, node.MTG.symbol)

                # If the component needs further initialisations
                if haskey(to_init, node.MTG.symbol)
                    # Search if any is missing:
                    attr_not_found = setdiff(
                        to_init[node.MTG.symbol],
                        collect(keys(node.attributes))
                    )

                    if length(attr_not_found) == 0
                        # If not, initialise the LeafModels using attributes
                        @info "Initialising $(to_init[node.MTG.symbol]) using node attributes" maxlog = 1
                        models_node = copy(models[node.MTG.symbol])
                        if node[:Rₛ] == 416.68402099609375
                            print("node", node.id)
                        end

                        init_status!(
                            models_node;
                            NamedTuple(i => node[i] for i in to_init[node.MTG.symbol])...
                        )
                        node[:leaf_model] = models_node
                    else
                        # If some initialisations are not available from the node attributes:
                        for i in attr_not_found
                            push!(attrs_missing[node.MTG.symbol], i)
                        end
                    end
                else
                    # Else we initialise as is
                    node[:leaf_status] = models[node.MTG.symbol]
                end
            end
        end
        if any([length(value) > 0 for (key, value) in attrs_missing])
            err_msg = [string("\n", key, ": [", join(value, ", ", " and "), "]") for (key, value) in attrs_missing]
            @error string(
                "Some variables need to be initialised for some components before simulation:",
                join(err_msg, ", ", " and ")
            )
        end
    elseif verbose
        @info string(
            "All models are aleady initialised. Make a new model if you want to update the values."
        )
    end

    return nothing
end
