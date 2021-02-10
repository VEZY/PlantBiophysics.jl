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

# Conversions
include("conversions.jl")

# Atmosphere computations (vapor pressure...)
include("atmosphere.jl")

# Light interception
include("light_interception/generic_structs.jl")
include("light_interception/Ignore.jl")
include("light_interception/Translucent.jl")

# Photosynthesis related files:
include("photosynthesis/photosynthesis.jl")
include("photosynthesis/FvCB.jl")
include("photosynthesis/FvCBIter.jl")
include("photosynthesis/temperature-dependence.jl")

# Stomatal conductance related files:
include("conductances/stomatal/constant.jl")
include("conductances/stomatal/gs.jl")
include("conductances/stomatal/medlyn.jl")

# Boundary layer conductance:
include("conductances/boundary/gb.jl")

# Energy balance
include("energy/longwave_energy.jl")
include("energy/energy_balance.jl")
include("energy/Monteith.jl")

# File IO
include("io/read_model.jl")

# File IO:
export read_model
export is_model

# Atmosphere
export e
export e_sat
export e_sat_slope
export air_density
export Atmosphere

# Conversions
export rh_from_vpd
export ms_to_mol

# Energy balance
export EnergyModel
export black_body
export grey_body
export psychrometer_constant
export net_longwave_radiation
export energy_balance # main interface to user
export net_radiation  # each energy model implement a method for this function (called from energy_balance)
export Monteith       # a struct to hold the values for the model of Monteith and Unsworth (2013)

# structure for light interception
export Translucent
export Ignore
export OpticalProperties
export σ
export InterceptionModel

# Geometry
export GeometryModel
export AbstractGeom

# Photosynthesis
export AModel
export Fvcb # Parameters for the Farquhar et al. (1980) model
export FvcbIter
export Constants
export assimilation!
export photosynthesis

# Conductances
export GsModel
export gbh_to_gbw
export gbₕ_free
export gbₕ_forced
export gs
export Medlyn

# Physical constants
export Constants

# Temporary structures (to move to another package)
export Translucent
export Ignore

# Components (structures that hold models)
export PhotoComponent
export Leaf
export Metamer

end
