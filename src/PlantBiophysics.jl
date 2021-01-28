module PlantBiophysics

# For model parameters (efficient and still mutable!)
using MutableNamedTuples

# For reading YAML:
using YAML
using OrderedCollections

# Generic structures:
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

# File IO
include("io/read_model.jl")

# File IO:
export read_model
export is_model

# structure for photosynthesis
export Fvcb # Parameters for the Farquhar et al. (1980) model
export FvcbIter
export Constants
export assimiliation
export gs
export Medlyn

# Temporary structures (to move to another package)
export Translucent
export Ignore

# Structure that hold models
export Leaf

end
