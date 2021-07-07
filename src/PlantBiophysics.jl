module PlantBiophysics

# For model parameters (efficient and still mutable!)
using Base:nonnothingtype
using MutableNamedTuples

# For reading YAML:
using YAML
using OrderedCollections

import DataFrames.DataFrame # For convenience transformations
import DataFrames.Not
import Base.show

# Generic structures:
include("structs/Abstract_model_structs.jl")
include("structs/concrete_component_structs.jl")

# Physical constants:
include("structs/constants.jl")

# Models helpers:
include("models_helpers.jl")

# Atmosphere computations (vapor pressure...)
include("structs/atmosphere.jl")

# Conversions
include("conversions.jl")

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
include("conductances/stomatal/stomatal_conductance.jl")
include("conductances/stomatal/constantGs.jl")
include("conductances/stomatal/medlyn.jl")

# Boundary layer conductance:
include("conductances/boundary/gb.jl")

# Energy balance
include("energy/longwave_energy.jl")
include("energy/energy_balance.jl")
include("energy/Missing.jl")
include("energy/Monteith.jl")

# File IO
include("io/read_model.jl")

# File IO:
export read_model
export is_model

# Physical constants
export Constants

# Status
export init_status!

# Get models informations
export variables, variables_typed
export inputs, outputs
export to_initialise, is_initialised

# Atmosphere
export vapor_pressure
export e_sat
export e_sat_slope
export air_density
export Atmosphere
export Weather

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
export energy_balance! # main interface to user
export Monteith       # a struct to hold the values for the model of Monteith and Unsworth (2013)
export latent_heat
export sensible_heat
export γ_star
export latent_heat_vaporization

# structure for light interception
export Translucent
export Ignore
export OpticalProperties
export σ
export AbstractInterceptionModel

# Photosynthesis
export AbstractAModel
export ConstantA
export Fvcb # Parameters for the Farquhar et al. (1980) model
export FvcbIter # To update...
export Constants
export photosynthesis!
export photosynthesis
export assimilation!

# Conductances
export AbstractGsModel
export gbh_to_gbw
export gbₕ_free
export gbₕ_forced
export gs, gs!
export Medlyn
export ConstantGs

# Temporary structures (to move to another package)
export Translucent
export Ignore
export get_km, Γ_star, arrhenius, get_J, gs_closure, get_Cᵢⱼ,get_Cᵢᵥ,get_Dₕ
export init_variables_manual, init_variables, Fvcb_net_assimiliation
export get_component_type, get_process, get_model, instantiate, get_component_type

export AbstractModel

# Components (structures that hold models)
export AbstractComponentModel
export LeafModels

# Convenience functions
export DataFrame

end
