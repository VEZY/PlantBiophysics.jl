
"""
    LeafModels(interception, energy_balance, photosynthesis, stomatal_conductance, status)
    LeafModels(;interception = missing, energy_balance = missing, photosynthesis = missing,
        stomatal_conductance = missing,status...)

[`LeafModels`](@ref) is a structure used to list the processes and associated models for
photosynthetic components. It can be a leaf, a leaflet, or really any kind of component that
has a photosynthetic activity. The name `LeafModels` was chosen not because it is generic,
but because it is short, simple and self-explanatory.

## Processes

[`LeafModels`](@ref) implements four processes:

- `interception <: Union{Missing,AbstractInterceptionModel}`: An interception model.
- `energy_balance <: Union{Missing,AbstractEnergyModel}`: An energy model, *e.g.* [`Monteith`](@ref).
- `photosynthesis <: Union{Missing,AbstractAModel}`: A photosynthesis model, *e.g.* [`Fvcb`](@ref)
- `stomatal_conductance <: Union{Missing,AbstractGsModel}`: A stomatal conductance model,
    *e.g.* [`Medlyn`](@ref) or [`ConstantGs`](@ref)

Like all other [`AbstractComponentModel`](@ref), [`LeafModels`](@ref) also has a `status` field:

- `status <: MutableNamedTuple`: a mutable named tuple to track the status of the component,
    *i.e.* the variables and their values. Values are set to `-999.99` if not provided as
    keywords arguments (see examples).

!!! note
    The status field depends on the input models. You can get the variables needed by a model
    using [`variables`](@ref) on the instantiation of a model. You can also use [`inputs`](@ref)
    and [`outputs`](@ref) instead.

## Examples

A leaf with a width of 0.03 m, that uses the Monteith and Unsworth (2013) model for energy
balance, the Farquhar et al. (1980) model for photosynthesis, and a constant stomatal
conductance for CO₂ of 0.0011 with no residual conductance.

```@setup usepkg
using PlantBiophysics
```

```@example usepkg
leaf = LeafModels(
    energy_balance = Monteith(),
    photosynthesis = Fvcb(),
    stomatal_conductance = ConstantGs(0.0, 0.0011)
)
```

No variables were given as keyword arguments, that means that the status of the leaf is not
set yet, and all variables are initialised to `-999.99`. This component cannot be simulated
yet.

To know which variables we need to initialise for a simulation, we use [`to_initialise`](@ref):

```@example usepkg
to_initialise(leaf)
```

The meaning and units of the variables can be found on documentation of each model,
*e.g.* [here for photosynthesis](https://vezy.github.io/PlantBiophysics.jl/stable/models/photosynthesis/).

We can now provide values for these variables:

```@example usepkg
leaf = LeafModels(
    energy_balance = Monteith(),
    photosynthesis = Fvcb(),
    stomatal_conductance = ConstantGs(0.0, 0.0011),
    Rₛ = 13.747, sky_fraction = 1.0, d = 0.03
)
```

We can now simulate the leaf, *e.g.* for the energy_balance (coupled to photosynthesis and
stomatal conductance):

```@example usepkg
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

energy_balance!(leaf,meteo)

DataFrame(leaf)
```
"""
struct ModelList{M,S<:AbstractStatus}
    models::M
    status::S
end

# General interface:
function ModelList(; status=MutableNamedTuple(), datatype=MutableNamedTuple, kwargs...)
    ref_vars = init_variables((; kwargs...)...)
    status = homogeneous_type_steps(ref_vars, status, datatype)
    ModelList((; kwargs...), status)
end

function homogeneous_type_steps(ref_vars, vars, datatype=MutableNamedTuple)
    vars_vals = collect(values(vars))
    length_vars = [length(i) for i in vars_vals]

    if any(length_vars .> 1)
        # One of the variable is given as an array, meaning this is actually several
        # time-steps. In this case we make an array of vars.
        max_length_st = maximum(length_vars)
        for i in eachindex(vars_vals)
            # If the ith vars has length one, repeat its value to match the max time-steps:
            if length_vars[i] == 1
                vars_vals[i] = repeat([vars_vals[i]], max_length_st)
            else
                length_vars[i] != max_length_st && @error "$(keys(vars)[i]) should be length $max_length_st or 1"
            end
        end

        # Making a vars for each ith value in the user vars:
        vars_array = datatype[]
        for i in 1:max_length_st
            push!(
                vars_array,
                init_variables_manual(
                    instantiate_status_struct(datatype, ref_vars),
                    NamedTuple{keys(vars)}(j[i] for j in vars_vals)
                )
            )
        end

        return TimeSteps(vars_array)
    else
        return Status(vars)
    end
end

"""
    Base.copy(l::LeafModels)
    Base.copy(l::LeafModels, status)

Copy a [`LeafModels`](@ref), eventually with new values for the status.
"""
function Base.copy(l::T) where {T<:ModelList}
    ModelList(
        l.models,
        deepcopy(l.status)
    )
end

function Base.copy(l::T, status::S) where {T<:ModelList,S<:AbstractStatus}
    ModelList(
        l.models,
        status
    )
end
