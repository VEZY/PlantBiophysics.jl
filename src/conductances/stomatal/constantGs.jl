
"""
Constant stomatal conductance for CO₂ struct.

# Arguments

- `g0`: intercept.
- `gs`: stomatal conductance.
- `gs_min = 0.001`: residual conductance. We consider the residual conductance being different
 from `g0` because in practice `g0` can be negative when fitting real-world data.

Then used as follows:
Gs = ConstantGs(0.0,0.1)
Gₛ = Gs.g0 + Gs.gs * A
"""
struct ConstantGs{T} <: AbstractGsModel
    g0::T
    gs::T
    gs_min::T
end

function ConstantGs(g0,gs,gs_min)
    ConstantGs(promote(g0,gs,gs_min)...)
end

ConstantGs(g0,gs) = ConstantGs(g0,gs,oftype(gs,0.001))

function inputs(::ConstantGs)
    (:Gₛ,)
end

function outputs(::ConstantGs)
    (:Gₛ,)
end

Base.eltype(x::ConstantGs) = typeof(x).parameters[1]


"""
Constant stomatal closure

# Note

`meteo` is just declared here for compatibility with other formats of calls.
"""
function gs_closure(leaf::LeafModels{I,E,A,Gs,S},meteo=missing) where {I,E,A,Gs<:ConstantGs,S}
    leaf.stomatal_conductance.gs - leaf.stomatal_conductance.g0
end


"""
Constant stomatal conductance for CO₂ (mol m-2 s-1).

# Note

`meteo` or `gs_mod` are just declared here for compatibility with the call from
photosynthesis (need a constant way of calling the functions).
"""
function gs(leaf::LeafModels{I,E,A,Gs,S},gs_mod) where {I,E,A,Gs<:ConstantGs,S}
    leaf.stomatal_conductance.gs
end

function gs(leaf::LeafModels{I,E,A,Gs,S},meteo::M) where {I,E,A,Gs<:ConstantGs,S,M<:Atmosphere}
    leaf.stomatal_conductance.gs
end

function gs!(leaf::LeafModels{I,E,A,Gs,S},gs_mod) where {I,E,A,Gs<:ConstantGs,S}
    leaf.status.Gₛ = leaf.stomatal_conductance.gs
end

function gs!(leaf::LeafModels{I,E,A,Gs,S},meteo::M) where {I,E,A,Gs<:ConstantGs,S,M<:Atmosphere}
    leaf.status.Gₛ = leaf.stomatal_conductance.gs
end
