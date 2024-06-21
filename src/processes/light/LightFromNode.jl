"""
    LightFromMTGNode()

Read the light interception model from the MTG nodes.

!!! Will be depreciated at some point, see https://github.com/VirtualPlantLab/PlantSimEngine.jl/issues/74
"""
struct LightFromMTGNode <: AbstractLight_InterceptionModel end

"""
    run!(object, meteo, constants = Constants())

Read the light interception of a node from its attributes, and set the status of the node to this value.
"""
function PlantSimEngine.run!(::LightFromMTGNode, models, status, meteo, constants, extra=nothing)
    status.Ra_SW_f = status.node.Ra_SW_f[PlantMeteo.rownumber(meteo)]
    status.aPPFD = status.node.Ra_PAR_f[PlantMeteo.rownumber(meteo)] * 4.57
    status.sky_fraction = status.node.sky_fraction[PlantMeteo.rownumber(meteo)]
end

PlantSimEngine.inputs_(::LightFromMTGNode) = NamedTuple()
PlantSimEngine.outputs_(::LightFromMTGNode) = (aPPFD=-Inf, Ra_SW_f=-Inf, sky_fraction=-Inf,)

PlantSimEngine.ObjectDependencyTrait(::Type{<:LightFromMTGNode}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:LightFromMTGNode}) = PlantSimEngine.IsTimeStepIndependent()
