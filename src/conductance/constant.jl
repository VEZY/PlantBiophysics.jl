
"""
Constant stomatal conductance for CO₂ struct.

Then used as follows:
Gs = ConstantGs(0.03,0.1)
Gₛ = Gs.g0 + Gs.gs * A
"""
struct ConstantGs{T} <: GsModel
 g0::T
 gs::T
end

"""
Constant stomatal conductance for CO₂.

Then used as follows:
Gₛ = g0 + Gs.gs * A

"""
function gs(Gs::ConstantGs)
    Gs.gs
end
