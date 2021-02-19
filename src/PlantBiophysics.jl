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
include("photosynthesis/constantA.jl")
include("photosynthesis/FvCB.jl")
include("photosynthesis/FvCBIter.jl")
include("photosynthesis/temperature-dependence.jl")

# Stomatal conductance related files:
include("conductances/stomatal/constantGs.jl")
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
export rh_from_e
export ms_to_mol
export mol_to_ms
export gbh_to_gbw
export gbw_to_gbh
export gsw_to_gsc
export gsc_to_gsw

# Energy balance
export AbstractEnergyModel
export black_body
export grey_body
export psychrometer_constant
export net_longwave_radiation
export energy_balance # main interface to user
export net_radiation!  # each energy model implement a method for this function (called from energy_balance)
export net_radiation
export Monteith       # a struct to hold the values for the model of Monteith and Unsworth (2013)
export latent_heat
export sensible_heat
export γ_star

# structure for light interception
export Translucent
export Ignore
export OpticalProperties
export σ
export AbstractInterceptionModel

# Geometry
export AbstractGeometryModel
export Geom1D # one dimensional geometry

# Photosynthesis
export AbstractAModel
export ConstantA
export Fvcb # Parameters for the Farquhar et al. (1980) model
export FvcbIter # To update...
export Constants
export assimilation!
export photosynthesis!
export photosynthesis

# Conductances
export AbstractGsModel
export gbh_to_gbw
export gbₕ_free
export gbₕ_forced
export gs
export Medlyn
export ConstantGs

# Physical constants
export Constants

# Temporary structures (to move to another package)
export Translucent
export Ignore
export get_km, Γ_star, arrhenius, get_J, gs_closure, get_Cᵢⱼ,get_Cᵢᵥ,get_Dₕ
export init_variables_manual, init_variables, Fvcb_net_assimiliation


export AbstractModel
export variables

# Components (structures that hold models)
export AbstractPhotoComponent
export Leaf
export Metamer

end
