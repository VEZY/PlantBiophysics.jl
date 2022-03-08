
"""
Constant stomatal conductance for CO₂ struct.

# Arguments

- `g0`: intercept (only used when calling from a photosynthesis model, *e.g.* Fvcb).
- `gs`: stomatal conductance.

Then used as follows:
Gs = ConstantGs(0.0,0.1)
"""
struct ConstantGs{T} <: AbstractGsModel
    g0::T
    gs::T
end

function ConstantGs(g0, gs)
    ConstantGs(promote(g0, gs)...)
end

ConstantGs(; g0 = 0.0, gs) = ConstantGs(g0, gs)

function inputs(::ConstantGs)
    (:Gₛ,)
end

function outputs(::ConstantGs)
    (:Gₛ,)
end

Base.eltype(x::ConstantGs) = typeof(x).parameters[1]


"""
Constant stomatal closure. Usually called from a photosynthesis model.

# Note

`meteo` is just declared here for compatibility with other formats of calls.
"""
function gs_closure(leaf::LeafModels{I,E,A,Gs,S}, meteo = missing) where {I,E,A,Gs<:ConstantGs,S}
    (leaf.stomatal_conductance.gs - leaf.stomatal_conductance.g0) / leaf.status.A
end


"""
Constant stomatal conductance for CO₂ (mol m-2 s-1).

# Note

`meteo` or `gs_mod` are just declared here for compatibility with the call from
photosynthesis (need a constant way of calling the functions).
"""
function gs!_(leaf::LeafModels{I,E,A,Gs,S}, gs_closure) where {I,E,A,Gs<:ConstantGs,S}
    leaf.status.Gₛ = leaf.stomatal_conductance.gs
end

function gs!_(leaf::LeafModels{I,E,A,Gs,S}, meteo::M, constants = Constants()) where {I,E,A,Gs<:ConstantGs,S,M<:AbstractAtmosphere}
    leaf.status.Gₛ = leaf.stomatal_conductance.gs
end
