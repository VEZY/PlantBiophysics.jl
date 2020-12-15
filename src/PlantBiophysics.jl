module PlantBiophysics

include("structs.jl")

# Photosynthesis related files:
include("photosynthesis/photosynthesis.jl")
include("photosynthesis/temperature-dependence.jl")

# Maybe to remove
export Constants
export Γ_star

end
