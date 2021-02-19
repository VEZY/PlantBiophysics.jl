
"""
Constant stomatal conductance for CO₂ struct.

Then used as follows:
Gs = ConstantGs(0.03,0.1)
Gₛ = Gs.g0 + Gs.gs * A
"""
struct ConstantGs{T} <: AbstractGsModel
 g0::T
 gs::T
end

function variables(::ConstantGs)
    ()
end

"""
Constant stomatal conductance for CO₂ (mol m-2 s-1).

Then used as follows:
Gₛ = g0 + Gs.gs * A

# Note
gs_vars is just declared here for compatibility with other formats of calls.
"""
function gs_closure(leaf::Leaf{G,I,E,A,<:ConstantGs,S},meteo=missing) where {G,I,E,A,S}
    leaf.stomatal_conductance.gs - leaf.stomatal_conductance.g0
end

function gs(leaf::Leaf{G,I,E,A,<:ConstantGs,S},gs_mod) where {G,I,E,A,S}
    leaf.stomatal_conductance.gs
end

function gs(leaf::Leaf{G,I,E,A,<:ConstantGs,S},meteo::M) where {G,I,E,A,S,M<:Atmosphere}
    leaf.stomatal_conductance.gs
end
