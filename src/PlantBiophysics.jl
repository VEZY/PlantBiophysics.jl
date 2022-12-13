module PlantBiophysics

import PlantSimEngine
import PlantSimEngine: @gen_process_methods, AbstractModel, TimeStepTable
import PlantSimEngine: Status, ModelList

import PlantMeteo
import PlantMeteo: Weather, AbstractAtmosphere

# For IO:
import YAML
import CSV
import OrderedCollections: OrderedDict
import Dates

import DataFrames.DataFrame # For convenience transformations
import DataFrames: Not, rename!, select!, select, dropmissing!, sort!, transform!
import DataFrames.names

import Base.show
import Base.getindex
import Base.length
import Base.iterate
import Base.keys
import LsqFit: curve_fit
using RecipesBase
import Statistics

# Generic process methods
include("processes/light/light_interception.jl")
include("processes/photosynthesis/photosynthesis.jl")
include("processes/conductances/stomatal/stomatal_conductance.jl")
include("processes/energy/energy_balance.jl")

# Conversions
include("conversions.jl")

# Light interception
include("processes/light/Ignore.jl")
include("processes/light/Beer.jl")
include("processes/light/Translucent.jl")

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

# Depreciations
include("depreciations/models.jl")

# File IO:
export read_model
export is_model
export read_weather
export read_walz
export read_licor6400

# Conversions
export ms_to_mol
export mol_to_ms
export gbh_to_gbw
export gbw_to_gbh
export gsw_to_gsc
export gsc_to_gsw

# Light interception
export AbstractLight_InterceptionModel
export light_interception, light_interception! # main interface to user
export Beer # a struct to hold the values for the Beer-Lambert law of light extinction

# Energy balance
export AbstractEnergy_BalanceModel
export black_body
export grey_body
export net_longwave_radiation
export energy_balance, energy_balance! # main interface to user
export Monteith       # a struct to hold the values for the model of Monteith and Unsworth (2013)
export latent_heat, sensible_heat

# structure for light interception
export Translucent
export Ignore
export OpticalProperties
export σ
export AbstractLight_InterceptionModel

# Photosynthesis
export AbstractPhotosynthesisModel
export ConstantA, ConstantAGs
export Fvcb # Parameters for the coupled Farquhar et al. (1980) model
export FvcbIter # To update...
export FvcbRaw # Parameters for the original Farquhar et al. (1980) model
export photosynthesis!
export photosynthesis
export photosynthesis!_

# Conductances
export AbstractStomatal_ConductanceModel
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
export Fvcb_net_assimiliation
export get_process, get_model, instantiate

# Parameters optimization
export fit

# Re-exporting the ModelList from PlantSimEngine
export ModelList

end
