
"""
Constant stomatal conductance for CO₂ struct.

# Arguments

- `g0`: intercept (only used when calling from a photosynthesis model, *e.g.* Fvcb).
- `Gₛ`: stomatal conductance.

Then used as follows:
Gs = ConstantGs(0.0,0.1)
"""
struct ConstantGs{T} <: AbstractStomatal_ConductanceModel
    g0::T
    Gₛ::T
end

function ConstantGs(g0, Gₛ)
    ConstantGs(promote(g0, Gₛ)...)
end

ConstantGs(; g0=0.0, Gₛ) = ConstantGs(g0, Gₛ)

function PlantSimEngine.inputs_(::ConstantGs)
    (Gₛ=-Inf,)
end

function PlantSimEngine.outputs_(::ConstantGs)
    (Gₛ=-Inf,)
end

Base.eltype(x::ConstantGs) = typeof(x).parameters[1]

"""
Constant stomatal closure. Usually called from a photosynthesis model.

# Note

`meteo` is just declared here for compatibility with other formats of calls.
"""
function gs_closure(::ConstantGs, models, status, meteo=missing, constants=nothing, extra=nothing)
    (models.stomatal_conductance.Gₛ - models.stomatal_conductance.g0) / status.A
end

"""
Constant stomatal conductance for CO₂ (mol m-2 s-1).

# Note

`meteo` or `gs_mod` are just declared here for compatibility with the call from
photosynthesis (need a constant way of calling the functions).
"""
function stomatal_conductance!_(::ConstantGs, models, status, gs_closure)
    status.Gₛ = models.stomatal_conductance.Gₛ
end

function stomatal_conductance!_(::ConstantGs, models, status, meteo, constants, extra=nothing)
    status.Gₛ = models.stomatal_conductance.Gₛ
end
