module PlantBiophysics

include("structs.jl")

# Photosynthesis related files:
include("photosynthesis/photosynthesis.jl")
include("photosynthesis/temperature-dependence.jl")

# structure for photosynthesis
export Fvcb # Parameters for the Farquhar et al. (1980) model


# Maybe to remove
export Constants
export Γ_star

end
