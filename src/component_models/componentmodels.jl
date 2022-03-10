"""
    ComponentModels(interception, energy, status)
    ComponentModels(;interception = missing, energy = missing, status...)

Generic component, which is a subtype of `AbstractComponentModel` implementing a component with
an interception model and an energy balance model. It can be anything such as a trunk, a
solar panel or else.

# Arguments

- `interception <: Union{Missing,AbstractInterceptionModel}`: An interception model.
- `energy <: Union{Missing,AbstractEnergyModel}`: An energy model.
- `status <: MutableNamedTuple`: a mutable named tuple to track the status (*i.e.* the variables) of
the component. Values are set to `0.0` if not provided as VarArgs (see examples)

# Examples

```julia
# An internode in a plant:
ComponentModels(energy = Monteith())
```
"""
struct ComponentModels{I<:Union{Missing,AbstractInterceptionModel},E<:Union{Missing,AbstractEnergyModel},S<:MutableNamedTuple} <: AbstractComponentModel
    interception::I
    energy::E
    status::S
end

function ComponentModels(; interception = missing, energy = missing, status...)
    status = init_variables_manual(interception, energy; status...)
    ComponentModels(interception, energy, status)
end


"""
    Base.copy(l::LeafModels)
    Base.copy(l::LeafModels, status)

Copy a [`ComponentModels`](@ref), eventually with new values for the status.
"""
function Base.copy(l::T) where {T<:ComponentModels}
    ComponentModels(
        l.interception,
        l.energy,
        deepcopy(l.status)
    )
end

function Base.copy(l::T, status) where {T<:ComponentModels}
    ComponentModels(
        l.interception,
        l.energy,
        status
    )
end
