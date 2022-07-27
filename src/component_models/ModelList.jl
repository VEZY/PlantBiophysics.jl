
"""
    ModelList(models::M, status::S)
    ModelList(; status=MutableNamedTuple(), datatype=MutableNamedTuple, kwargs...)

A structure used to list the models for a simulation (`models`), and the associated
initialized variables (`status`).

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
leaf = ModelList(
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

The meaning and units of the variables can be found on the documentation of each model,
*e.g.* [here for photosynthesis](https://vezy.github.io/PlantBiophysics.jl/stable/models/photosynthesis/).

We can now provide values for these variables:

```@example usepkg
leaf = ModelList(
    energy_balance = Monteith(),
    photosynthesis = Fvcb(),
    stomatal_conductance = ConstantGs(0.0, 0.0011),
    status = (Rₛ = 13.747, sky_fraction = 1.0, d = 0.03, PPFD = 1500)
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
struct ModelList{M,S<:AbstractStatus} <: AbstractComponentModel
    models::M
    status::S
end

# General interface:
function ModelList(; status=MutableNamedTuple(), datatype=MutableNamedTuple, kwargs...)
    ref_vars = init_variables((; kwargs...)...)
    status = homogeneous_type_steps(ref_vars, status, datatype)
    ModelList((; kwargs...), status)
end

"""
    homogeneous_type_steps(ref_vars, vars, datatype=MutableNamedTuple)

Return a [`Status`](@ref) or [`TimeSteps`](@ref) based on the length of the variables in
vars. `ref_vars` is a struct with the default values of all the variables needed by the
models. `datatype` is the type used to hold the status inside the Status.
"""
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
        vars = Status(
            init_variables_manual(
                instantiate_status_struct(datatype, ref_vars),
                vars
            )
        )
        return vars
    end
end

"""
    Base.copy(l::ModelList)
    Base.copy(l::ModelList, status)

Copy a [`ModelList`](@ref), eventually with new values for the status.
"""
function Base.copy(m::T) where {T<:ModelList}
    ModelList(
        m.models,
        deepcopy(m.status)
    )
end

function Base.copy(m::T, status::S) where {T<:ModelList,S<:AbstractStatus}
    ModelList(
        m.models,
        status
    )
end
