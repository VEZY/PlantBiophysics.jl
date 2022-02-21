"""
    pull_status(node)

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
transform!(mtg, :leaf_model => (x -> energy_balance!(x, meteo)), ignore_nothing = true)
# Pull the simulation results into the MTG attributes:
transform!(mtg, pull_status)
# Now the simulated variables are available from the MTG attributes field:
names(mtg)
```
"""
function pull_status(node)
    if node[:leaf_model] !== nothing
        append!(node, node[:leaf_model].status)
    end
end


function pull_status(node, key::T) where {T<:Union{AbstractArray,Tuple}}
    if node[:leaf_model] !== nothing
        st = node[:leaf_model].status
        vars = findall(x -> x in key, collect(keys(st)))
        append!(node, Dict(keys(st)[i] => st[i] for i in vars))
    end
end

function pull_status(node, key::T) where {T<:Symbol}
    if node[:leaf_model] !== nothing
        append!(node, (; key => getproperty(node[:leaf_model].status, key)))
    end
end
