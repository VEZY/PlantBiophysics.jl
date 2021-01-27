module PlantBiophysics

using MutableNamedTuples

include("structs.jl")

# Photosynthesis related files:
include("photosynthesis/photosynthesis.jl")
include("photosynthesis/FvCB.jl")
include("photosynthesis/FvCBIter.jl")
include("photosynthesis/temperature-dependence.jl")

# stomatal conductance related files:
include("conductance/constant.jl")
include("conductance/gs.jl")
include("conductance/medlyn.jl")

# structure for photosynthesis
export Fvcb # Parameters for the Farquhar et al. (1980) model
export FvcbIter
export Constants
export assimiliation
export gs
export Medlyn

end
