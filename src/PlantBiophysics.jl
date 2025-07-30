module PlantBiophysics

import PlantSimEngine
import PlantSimEngine: @process, AbstractModel, TimeStepTable
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

# γ_star
include("processes/γ_star.jl")

# Light interception
include("processes/light/Ignore.jl")
include("processes/light/Beer.jl")
include("processes/light/Beer_shortwave.jl")
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
# include("processes/energy/Missing.jl")
include("processes/energy/Monteith.jl")

# File IO
include("io/read_model.jl")
include("io/read_walz.jl")
include("io/read_licor6400.jl")
include("io/read_licor6800.jl")
include("io/read_ess_dive.jl")

# Parameters optimization
include("fitting/fit_FvCB.jl")
include("fitting/fit_Medlyn.jl")
include("fitting/fit_Beer.jl")

# Depreciations
include("depreciations/models.jl")

# File IO:
export read_model
export is_model
export read_walz, read_licor6400, read_licor6800, read_ess_dive

# Conversions
export ms_to_mol
export mol_to_ms
export gbh_to_gbw
export gbw_to_gbh
export gsw_to_gsc
export gsc_to_gsw

# Light interception
export AbstractLight_InterceptionModel
export Beer, BeerShortwave  # structs to hold the values for the Beer-Lambert law of light extinction

# Energy balance
export AbstractEnergy_BalanceModel
export black_body
export grey_body
export net_longwave_radiation
export Monteith       # a struct to hold the values for the model of Monteith and Unsworth (2013)
export latent_heat, sensible_heat

# structure for light interception
export Translucent
export LightIgnore
export OpticalProperties
export σ
export AbstractLight_InterceptionModel

# Photosynthesis
export AbstractPhotosynthesisModel
export ConstantA, ConstantAGs
export Fvcb # Parameters for the coupled Farquhar et al. (1980) model
export FvcbIter # To update...
export FvcbRaw # Parameters for the original Farquhar et al. (1980) model

# Conductances
export AbstractStomatal_ConductanceModel
export gbh_to_gbw
export gbₕ_free
export gbₕ_forced
export Medlyn
export ConstantGs

# Model helpers
export get_km, Γ_star, arrhenius, get_J, gs_closure, get_Cᵢⱼ, get_Cᵢᵥ, get_Dₕ
export Fvcb_net_assimiliation
export get_process, get_model, instantiate

end
