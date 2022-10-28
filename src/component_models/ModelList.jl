
"""
    ModelList(models::M, status::S)
    ModelList(;
        status=MutableNamedTuple(),
        status_type=MutableNamedTuple,
        type_promotion=nothing,
        variables_check=true,
        kwargs...
    )

A structure used to list the models for a simulation (`models`), and the associated
initialized variables (`status`).

!!! note
    The status field depends on the input models. You can get the variables needed by a model
    using [`variables`](@ref) on the instantiation of a model. You can also use [`inputs`](@ref)
    and [`outputs`](@ref) instead.


# Arguments

    - `models`: a list of models to be used in the simulation. Usually a `NamedTuple`, but
    can be any other structure that implements `getproperty`.
    - `status`: a structure containing the initializations for the variables for the models.
    - `status_type`: the type of the status structure. `MutableNamedTuple` by default.
    - `type_promotion`: optional type conversion for the variables with default values.
    `nothing` by default, *i.e.* no conversion. Note that conversion is not applied to the
    variables input by the user as `kwargs` (need to do it manually).
    Should be provided as a Dict with current type as keys and new type as values.
    - `variables_check=true`: check that all needed variables are initialized by the user.
    - `kwargs`: the models, named after the process they simulate.

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
set yet, and all variables are initialized to `typemin(Type)`, *i.e.* `-Inf` for floating
point numbers. This component cannot be simulated yet.

To know which variables we need to initialize for a simulation, we use [`to_initialize`](@ref):

```@example usepkg
to_initialize(leaf)
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

If we want to use special types for the variables, we can use the `type_promotion` argument:

```@example usepkg
leaf = ModelList(
    energy_balance = Monteith(),
    photosynthesis = Fvcb(),
    stomatal_conductance = ConstantGs(0.0, 0.0011),
    status = (Rₛ = 13.747, sky_fraction = 1.0, d = 0.03, PPFD = 1500),
    type_promotion = Dict(Float64 => Float32)
)
```
"""
struct ModelList{M,S<:TimeStepTable}
    models::M
    status::S
end

# General interface:
function ModelList(;
    status=nothing,
    status_type=MutableNamedTuple,
    type_promotion=nothing,
    variables_check=true,
    kwargs...
)
    # Get all the variables needed by the models and their default values:
    mods = (; kwargs...)
    ref_vars = merge(init_variables(mods; verbose=false)...)
    # Convert their type to the one required by the user:
    ref_vars = convert_vars(type_promotion, ref_vars)

    status = homogeneous_type_steps(ref_vars, status, status_type)

    model_list = ModelList(mods, status)

    variables_check && !is_initialized(model_list)

    return model_list
end

"""
    homogeneous_type_steps(ref_vars, vars, datatype=MutableNamedTuple)

Return a [`Status`](@ref) or [`TimeStepTable`](@ref) based on the length of the variables in
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
            status_i = NamedTuple{keys(vars)}(j[i] for j in vars_vals)
            # NB: we use a NamedTuple here because MutableNamedTuple does not work with
            # Particles.
            push!(
                vars_array,
                merge_status(
                    convert_status(datatype, ref_vars),
                    convert_status(datatype, status_i)
                )
            )
        end

        return TimeStepTable(vars_array)
    else
        vars = Status(
            merge_status(
                convert_status(datatype, ref_vars),
                convert_status(datatype, vars)
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

function Base.copy(m::T, status::S) where {T<:ModelList,S<:TimeStepTable}
    ModelList(
        m.models,
        status
    )
end


"""
    convert_vars(type_promotion::Dict{DataType,DataType}, ref_vars)
    convert_vars(type_promotion::Nothing, ref_vars)

Convert the status variables to the type specified in the type promotion dictionary.

# Examples

If we want all the variables that are Reals to be Float32, we can use:

```julia
ref_vars = init_variables(energy_balance=Monteith(), photosynthesis=Fvcb(), stomatal_conductance=Medlyn(0.03, 12.0))
type_promotion = Dict(Real => Float32)

convert_vars(type_promotion, ref_vars)
```
"""
function convert_vars(type_promotion::Dict{DataType,DataType}, ref_vars)
    dict_ref_vars = Dict{Symbol,Any}(zip(keys(ref_vars), values(ref_vars)))
    for (suptype, newtype) in type_promotion
        vars = []
        for var in keys(ref_vars)
            if isa(dict_ref_vars[var], suptype)
                dict_ref_vars[var] = convert(newtype, dict_ref_vars[var])
                push!(vars, var)
            end
        end
        length(vars) > 1 && @info "$(join(vars, ", ")) are $suptype and were promoted to $newtype"
    end

    return NamedTuple(dict_ref_vars)
end

# This is the generic one, with no convertion:
function convert_vars(type_promotion::Nothing, ref_vars)
    return ref_vars
end


function Base.show(io::IO, t::ModelList)
    print(io, dep(t, verbose=false))
    print(io, status(t))
end
