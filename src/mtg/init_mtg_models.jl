"""
    init_mtg_models!(mtg, models::Dict{String,<:AbstractModel})

Initialise the components of an MTG (*i.e.* nodes) with the corresponding models.

The function checks if the models associated to each component of the MTG are fully initialized,
and if not, it tries to initialise the variables using the MTG attributes of the same name,
and if not found, returns an error.

```julia
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","scene","opf","coffee.opf")
mtg = read_mtg(file)

models = Dict(
    "Leaf" =>
        LeafModels(
            energy = monteith,
            photosynthesis = fvcb,
            stomatal_conductance = medlyn,
            d = 0.03
        ),
    "Metamer" =>
            LeafModels(
            energy = monteith,
            Rₛ = 10.,
            skyFraction = 1.,
            d = 0.03
        )
)

init_mtg_models!(mtg, models)
```
"""
function init_mtg_models!(mtg, models::Dict{String,<:AbstractModel}; verbose = true)

    # Check if all components have a model
    if verbose
        #! TO DO
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
        # node = get_node(mtg, 816)
        traverse!(
            mtg,
            function (node)
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
                            models_node = models[node.MTG.symbol]
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
        )
        if any([length(value) > 0 for (key, value) in attrs_missing])
            err_msg = [string("\n", key, ": [", join(value, ", ", " and "), "]") for (key, value) in attrs_missing]
            @error string(
                "Some variables need to be initialised for some components before simulation:",
                join(err_msg, ", ", " and ")
            )
        end
    end

    return nothing
end
