"""
    photosynthesis(leaf::AbstractComponentModel,meteo,constants = Constants())
    photosynthesis!(leaf::AbstractComponentModel,meteo,constants = Constants())
    photosynthesis!(object::Dict{String,PlantBiophysics.AbstractComponentModel},
        meteo::Atmosphere,constants = Constants())

Generic photosynthesis model for photosynthetic organs. Computes the assimilation and
stomatal conductance according to the models set for `leaf`, or for each component in
`object`.

The models used are defined by the types of the `photosynthesis` and `stomatal_conductance`
fields of `leaf`. For exemple to use the implementation of the Farquhar–von Caemmerer–Berry
(FvCB) model (see [`photosynthesis`](@ref)), the `leaf.photosynthesis` field should be of type
[`Fvcb`](@ref).

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

# Using Fvcb model:
leaf = LeafModels(photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = meteo.VPD)

photosynthesis(leaf, meteo)

# Using a model file:
model = read_model("a-model-file.yml")

# Initialising the mandatory variables:
init_status!(model, Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = meteo.VPD)

# Running a simulation for all component types in the same scene:
photosynthesis!(model, meteo)
model["Leaf"].status.A

```
"""
function photosynthesis(leaf::AbstractComponentModel,meteo,constants = Constants())
    leaf_tmp = deepcopy(leaf)
    photosynthesis!(leaf_tmp, meteo, constants)
    leaf_tmp.status
end

function photosynthesis!(leaf::AbstractComponentModel,meteo,constants = Constants())
    is_init = is_initialised(leaf,leaf.photosynthesis,leaf.stomatal_conductance)
    !is_init && error("Some variables must be initialized before simulation")
    assimilation!(leaf, meteo, constants)
end


function photosynthesis!(object::Dict{String,PlantBiophysics.AbstractComponentModel},
    meteo::Atmosphere,constants = Constants())

    for i in keys(object)
        photosynthesis!(object[i],meteo,constants)
    end
    return nothing
end
