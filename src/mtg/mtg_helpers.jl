"""
    pull_status!(node)

Copy the status of a node's LeafModel (*i.e.* the outputs of the simulations) into the MTG
attributes. This function is used when we need to compute further the simulation outputs with
*e.g.* [`transform!`](@ref).

# Notes

Carefull, this function makes a copy, so the values are then present at two locations (can
take a lot of memory space if using several plants).

# Examples

```julia
# Read the file
mtg = read_mtg(joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","scene","opf","coffee.opf"))

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

transform!(
    mtg,
    [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y) => :Rₛ,
    :Ra_PAR_f => (x -> x * 4.57) => :PPFD,
    ignore_nothing = true
)

# Initialising all components with their corresponding models and initialisations:
init_mtg_models!(mtg, models)

# Make a simulation
transform!(mtg, :models => (x -> energy_balance!(x, meteo)), ignore_nothing = true)
# Pull the simulation results into the MTG attributes:
transform!(mtg, pull_status!)
# Now the simulated variables are available from the MTG attributes field:
names(mtg)
```
"""
function pull_status!(node)
    if node[:models] !== nothing
        append!(node, node[:models].status)
    end
end

function pull_status!(node, key::T) where {T<:Union{AbstractArray,Tuple}}
    if node[:models] !== nothing
        st = node[:models].status
        vars = findall(x -> x in key, collect(keys(st)))
        append!(node, Dict(keys(st)[i] => st[i] for i in vars))
    end
end

function pull_status!(node, key::T) where {T<:Symbol}
    if node[:models] !== nothing
        append!(node, (; key => getproperty(node[:models].status, key)))
    end
end

"""
    pull_status_step!(node)

Copy the status of a node's LeafModel (*i.e.* the outputs of the simulations) into the MTG
attributes. New attributes are stored as vectors, one value per time-step.

See [`pull_status!`](@ref) for storing attributes as is (no vector transformation).
"""
function pull_status_step!(node; attr_name = :models)
    if node[attr_name] !== nothing
        st = node[attr_name].status
        vars = collect(keys(st))
        for i in vars
            if node[i] === nothing
                # If the attribute does not exist, create a vector of one value with it
                node[i] = typeof(st[i])[st[i]]
            elseif typeof(node[i]) <: AbstractArray
                # If it does exist and is already an array, push the new value
                push!(node[i], st[i])
            else
                # If the value already exist but is not an array, make an array out of it
                # and push the new value. This case happens when dealing with initialised
                # variables that have only one value
                node[i] = typeof(st[i])[node[i]]
                push!(node[i], st[i])
            end
        end
    end
end
