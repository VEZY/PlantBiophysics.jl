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
import DataFrames: Not, rename!, select!, select, dropmissing!, sort!, transform!
import Base.show
import Base.getindex
import Base.length
import Base.iterate
import Base.keys
import Impute.locf # For filling missing values in comments in Walz to identify curves
import LsqFit: curve_fit
using RecipesBase
import Statistics: mean

# Abstract structures:
include("Abstract_model_structs.jl")

# Status
include("component_models/Status.jl")

# Component models
include("component_models/ModelList.jl")

# Status helpers
include("component_models/get_status.jl")

# Atmosphere
include("climate/atmosphere.jl")
include("climate/weather.jl")

# Automatic process methods generation:
include("processes/process_methods_generation.jl")
include("processes/models_inputs_outputs.jl")
include("processes/model_initialisation.jl")

# Copy component models
include("component_models/copy.jl")

# Generic process methods
include("processes/light_interception/generic_structs.jl")
include("processes/photosynthesis/photosynthesis.jl")
include("processes/conductances/stomatal/stomatal_conductance.jl")
include("processes/energy/energy_balance.jl")

# Physical constants:
include("constants.jl")

# Atmosphere computations (vapor pressure...)
include("climate/variables_computations.jl")

# Checks for status and weather (same length):
include("checks/status_weather_corresp.jl")

# Conversions
include("conversions.jl")
include("dataframe.jl")

# Light interception
include("processes/light_interception/Ignore.jl")
include("processes/light_interception/Translucent.jl")

# Photosynthesis related files:
include("processes/photosynthesis/constantA.jl")
include("processes/photosynthesis/constantAGs.jl")
include("processes/photosynthesis/FvCB.jl")
include("processes/photosynthesis/FvCBIter.jl")
include("processes/photosynthesis/FvCBRaw.jl")
include("processes/photosynthesis/temperature-dependence.jl")

# Stomatal conductance related files:
include("processes/conductances/stomatal/constantGs.jl")
include("processes/conductances/stomatal/medlyn.jl")

# Boundary layer conductance:
include("processes/conductances/boundary/gb.jl")

# Energy balance
include("processes/energy/longwave_energy.jl")
include("processes/energy/Missing.jl")
include("processes/energy/Monteith.jl")

# File IO
include("io/read_model.jl")
include("io/read_weather.jl")
include("io/read_licor6400.jl")
include("io/read_walz.jl")

# Parameters optimization
include("fitting/fit.jl")
include("fitting/fit_FvCB.jl")
include("fitting/fit_Medlyn.jl")

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
export read_licor6400

# Physical constants
export Constants

# Status
export init_status!
export Status, TimeSteps

# ModelList
export ModelList

# Get models informations
export variables, variables_typed
export inputs, outputs
export inputs_, outputs_
export to_initialize, is_initialized

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
export ConstantA, ConstantAGs
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
export stomatal_conductance, stomatal_conductance!
export Medlyn
export ConstantGs

# Temporary structures (to move to another package)
export Translucent
export Ignore

# Model helpers
export get_km, Γ_star, arrhenius, get_J, gs_closure, get_Cᵢⱼ, get_Cᵢᵥ, get_Dₕ
export init_variables_manual, init_variables, Fvcb_net_assimiliation
export get_process, get_model, instantiate
export init_mtg_models!

# Models
export AbstractModel

# Parameters optimization
export fit

# Convenience functions
export DataFrame, copy, getindex, status, pull_status!, length

# Model evaluation
export EF, RMSE, dr

end
