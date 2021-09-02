"""
    photosynthesis(object, meteo, constants = Constants())
    photosynthesis!(object, meteo, constants = Constants())

Generic photosynthesis model for photosynthetic organs. Computes the assimilation and
stomatal conductance according to the models set in (or each component in) `object`.

The models used are defined by the types of the `photosynthesis` and `stomatal_conductance`
fields of `leaf`. For exemple to use the implementation of the Farquhar–von Caemmerer–Berry
(FvCB) model (see [`photosynthesis`](@ref)), the `leaf.photosynthesis` field should be of type
[`Fvcb`](@ref).

# Arguments

- `object`: a [`Component`](@ref) struct ([`AbstractComponentModel`](@ref)), or a Dict/Array of.
- `meteo::Union{AbstractAtmosphere,Weather}`: meteorology structure, see [`Atmosphere`](@ref) or
[`Weather`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

# Using Fvcb model:
leaf = LeafModels(photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = meteo.VPD)

photosynthesis(leaf, meteo)

# ---Using several components---

leaf2 = copy(leaf)
leaf2.status.PPFD = 800.0

photosynthesis([leaf,leaf2],meteo)

# ---Using several meteo time-steps---

w = Weather([Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
             Atmosphere(T = 25.0, Wind = 1.5, P = 101.3, Rh = 0.55)], (site = "Test site,))

photosynthesis(leaf, w)

# ---Using several meteo time-steps and several components---

photosynthesis(Dict(:leaf1 => leaf, :leaf2 => leaf2), w)

# Using a model file:

model = read_model("a-model-file.yml")

# Initialising the mandatory variables:
init_status!(model, Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, Dₗ = meteo.VPD)

# Running a simulation for all component types in the same scene:
photosynthesis!(model, meteo)
model["Leaf"].status.A

```
"""
function photosynthesis(leaf::AbstractComponentModel, meteo::AbstractAtmosphere, constants = Constants())
    leaf_tmp = copy(leaf)
    photosynthesis!(leaf_tmp, meteo, constants)
    leaf_tmp.status
end

# photosynthesis over several objects (e.g. all leaves of a plant) in an Array
function photosynthesis!(object::O, meteo::AbstractAtmosphere, constants = Constants()) where O <: AbstractArray{<:AbstractComponentModel}

    for i in values(object)
        photosynthesis!(i, meteo, constants)
    end

return nothing
end

# photosynthesis over several objects (e.g. all leaves of a plant) in a kind of Dict.
function photosynthesis!(object::O, meteo::AbstractAtmosphere, constants = Constants()) where {O <: AbstractDict{N,<:AbstractComponentModel} where N}
    for (k, v) in object
        photosynthesis!(v, meteo, constants)
    end

return nothing
end


# same as the above but non-mutating
function photosynthesis(
    object::O,
    meteo::AbstractAtmosphere,
    constants = Constants()
    ) where O <: Union{AbstractArray{<:AbstractComponentModel},AbstractDict{N,<:AbstractComponentModel} where N}

    # Copy the objects only once before the computation for performance reasons:
    object_tmp = copy(object)

    # Computation:
    photosynthesis!(object_tmp, meteo, constants)

    return DataFrame(object_tmp)
end

# photosynthesis over several meteo time steps (called Weather) and possibly several components:
function photosynthesis!(
    object::T,
    meteo::Weather,
    constants = Constants()
    ) where T <: Union{AbstractArray{<:AbstractComponentModel},AbstractDict{N,<:AbstractComponentModel} where N}

    # Check if the meteo data and the status have the same length (or length 1)
    check_status_wheather(object, meteo)

    # Computing for each time-steps:
    for (i, meteo_i) in enumerate(meteo.data)
        # Each object in a time-step:
        for obj in object
            photosynthesis!(obj[i], meteo_i, constants)
        end
    end
end

# If we call weather with one component only, put it in an Array and call the function above
function photosynthesis!(object::AbstractComponentModel, meteo::Weather, constants = Constants())
    photosynthesis!([object], meteo, constants)
end

# photosynthesis over several meteo time steps (same as above) but non-mutating
function photosynthesis(
    object::T,
    meteo::Weather,
    constants = Constants()
    ) where T <: Union{AbstractComponentModel,AbstractDict{N,<:AbstractComponentModel} where N}

    object_tmp = copy(object)
    photosynthesis!(object_tmp, meteo, constants)

    return object_tmp
end

# The function that finally calls assimilation!:
function photosynthesis!(leaf::AbstractComponentModel, meteo::AbstractAtmosphere, constants = Constants())
    is_init = is_initialised(leaf, leaf.photosynthesis, leaf.stomatal_conductance)
    !is_init && error("Some variables must be initialized before simulation (see info message for more details)")
    return assimilation!(leaf, meteo, constants)
end

# The same function (calls assimilation!) but for LeafModels without meteo, so we have to check
# first if the leaf as several time-steps or not. NB: we could do it each time in the function
# just above but I prefer make a new method for performance reasons.
function photosynthesis!(leaf::AbstractComponentModel, meteo::Nothing = nothing, constants = Constants()) where {I,E,A,Gs}
    is_init = is_initialised(leaf, leaf.photosynthesis, leaf.stomatal_conductance)
    !is_init && error("Some variables must be initialized before simulation (see info message for more details)")

    if typeof(leaf.status) == MutableNamedTuples.MutableNamedTuple
        assimilation!(leaf, meteo, constants)
    else
        # We have several time-steps here
        for i in 1:length(leaf.status)
            assimilation!(leaf[i], meteo, constants)
        end

    end

end



"""
    check_status_meteo(component,weather)

Checks if a component status and the wheather have the same length, or
if they can be recycled (length 1)
"""
function check_status_wheather(
        component::LeafModels{I,E,A,Gs,<:Vector{MutableNamedTuples.MutableNamedTuple}},
        weather::Weather
    ) where {I,E,A,Gs}
   length(component.status) != length(weather.data) &&
    @error "component status should have the same number of time-steps than weather"
end

# here we only have one time-step in the status, so we use it for all time-steps
function check_status_wheather(
        component::LeafModels{I,E,A,Gs,<:MutableNamedTuples.MutableNamedTuple},
        weather::Weather
    )  where {I,E,A,Gs}
    nothing
end

# for several components as an array
function check_status_wheather(component::T, weather::Weather) where T <: AbstractArray{<:AbstractComponentModel}
    for i in component
        check_status_wheather(i, weather)
    end
end

# for several components as a Dict
function check_status_wheather(component::T, weather::Weather) where T <: AbstractDict{N,<:AbstractComponentModel} where N
    for (key, val) in component
        check_status_wheather(val, weather)
    end
end
