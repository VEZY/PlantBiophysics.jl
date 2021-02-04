module PlantBiophysics

# For model parameters (efficient and still mutable!)
using MutableNamedTuples

# For reading YAML:
using YAML
using OrderedCollections

# Generic structures:
include("structs.jl")

# Physical constants:
include("constants.jl")

# Light interception
include("light_interception/generic_structs.jl")
include("light_interception/Ignore.jl")
include("light_interception/Translucent.jl")

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

# structure for light interception
export Translucent
export Ignore
export OpticalProperties
export σ

# Photosynthesis
export Fvcb # Parameters for the Farquhar et al. (1980) model
export FvcbIter
export Constants
export assimilation
export gs
export Medlyn
export photosynthesis

# Temporary structures (to move to another package)
export Translucent
export Ignore

# Organs (structures that hold models)
export Leaf
export Metamer

end
