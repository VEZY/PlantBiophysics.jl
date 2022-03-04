module PlantBiophysics

# For model parameters (efficient and still mutable!)
using MutableNamedTuples

# For IO:
import YAML
import CSV
import OrderedCollections: OrderedDict
import MultiScaleTreeGraph
import Dates

import DataFrames.DataFrame # For convenience transformations
import DataFrames.Not
import DataFrames.rename!
import DataFrames: select!, select
import DataFrames.dropmissing!
import Base.show
import Base.getindex
import Impute.locf # For filling missing values in comments in Walz to identify curves
import LsqFit: curve_fit
using RecipesBase
import Statistics: mean

# Generic structures:
include("structs/Abstract_model_structs.jl")
include("structs/concrete_component_structs.jl")

# Physical constants:
include("structs/constants.jl")

# Atmosphere computations (vapor pressure...)
include("structs/atmosphere.jl")

# Models helpers:
include("models_helpers.jl")

# Conversions
include("conversions.jl")

# Automatic process methods generation:
include("process_methods_generation.jl")

# Light interception
include("light_interception/generic_structs.jl")
include("light_interception/Ignore.jl")
include("light_interception/Translucent.jl")

# Photosynthesis related files:
include("photosynthesis/photosynthesis.jl")
include("photosynthesis/constantA.jl")
include("photosynthesis/FvCB.jl")
include("photosynthesis/FvCBIter.jl")
include("photosynthesis/FvCBRaw.jl")
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
include("io/read_weather.jl")
include("io/read_walz.jl")

# Parameters optimization
include("fitting/fit.jl")
include("fitting/fit_FvCB.jl")

# Model evaluation
include("evaluation/statistics.jl")

# Compatibility with MultiScaleTreeGraph.jl
include("mtg/init_mtg_models.jl")
include("mtg/mtg_helpers.jl")

# Depreciations
include("depreciations/models.jl")

# File IO:
export read_model
export is_model
export read_weather
export read_walz

# Physical constants
export Constants

# Status
export init_status!

# Get models informations
export variables, variables_typed
export inputs, outputs, defaults
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
export Fvcb # Parameters for the coupled Farquhar et al. (1980) model
export FvcbIter # To update...
export FvcbRaw # Parameters for the original Farquhar et al. (1980) model
export Constants
export photosynthesis!
export photosynthesis
export photosynthesis!_

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

# Model helpers
export get_km, Γ_star, arrhenius, get_J, gs_closure, get_Cᵢⱼ, get_Cᵢᵥ, get_Dₕ
export init_variables_manual, init_variables, Fvcb_net_assimiliation
export get_component_type, get_process, get_model, instantiate, get_component_type
export init_mtg_models!

# Models
export AbstractModel

# Components (structures that hold models)
export AbstractComponentModel
export LeafModels, ComponentModels

# Parameters optimization
export fit

# Convenience functions
export DataFrame, copy, getindex, status, pull_status!, length

# Model evaluation
export EF, RMSE, dr

end
