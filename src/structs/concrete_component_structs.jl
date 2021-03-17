
"""
    LeafModels(interception, energy, photosynthesis, stomatal_conductance, status)
    LeafModels(;interception = missing, energy = missing, photosynthesis = missing,
        stomatal_conductance = missing,status...)

LeafModels component, which is a subtype of `AbstractComponentModel` implementing a component with
a photosynthetic activity. It could be a leaf, or a leaflet, or whatever kind of component
that is photosynthetic. The name `LeafModels` was chosen not because it is generic, but because it
is short, simple and self-explanatory.

# Arguments

- `interception <: Union{Missing,AbstractInterceptionModel}`: An interception model.
- `energy <: Union{Missing,AbstractEnergyModel}`: An energy model, e.g. [`Monteith`](@ref).
- `photosynthesis <: Union{Missing,AbstractAModel}`: A photosynthesis model, e.g. [`Fvcb`](@ref)
- `stomatal_conductance <: Union{Missing,AbstractGsModel}`: A stomatal conductance model, e.g. [`Medlyn`](@ref) or
[`ConstantGs`](@ref)
- `status <: MutableNamedTuple`: a mutable named tuple to track the status (*i.e.* the variables) of
the leaf. Values are set to `0.0` if not provided as VarArgs (see examples)

# Details

The status field depends on the input models. You can get the variables needed by a model using
[`variables`](@ref) on the instantiation of a model. Generally the variables are:

## Light interception model  (see [`AbstractInterceptionModel`](@ref))

- `Rₛ` (W m-2): net shortwave radiation (PAR + NIR). Often computed from a light interception model
- `PPFD` (μmol m-2 s-1): absorbed Photosynthetic Photon Flux Density
- `skyFraction` (0-2): view factor between the object and the sky for both faces.

## Energy balance model (see [`energy_balance`](@ref))

- `Tₗ` (°C): temperature of the object. Often computed from an energy balance model.
- `Rₗₗ` (W m-2): net longwave radiation for the object (TIR)
- `Cₛ` (ppm): stomatal CO₂ concentration
- `ψₗ` (kPa): leaf water potential
- `H` (W m-2): sensible heat flux
- `λE` (W m-2): latent heat flux
- `Dₗ` (kPa): vapour pressure difference between the surface and the saturation vapour

## Photosynthesis model (see [`photosynthesis`](@ref))

- `A` (μmol m-2 s-1): carbon assimilation
- `Gbₕ` (m s-1): boundary conductance for heat (free + forced convection)
- `Cᵢ` (ppm): intercellular CO₂ concentration

# Examples

```julia
# A leaf with a width of 0.03 m, that uses the Monteith and Unsworth (2013) model for energy
# balance, The Farquhar et al. (1980) model for photosynthesis, and a constant stomatal
# conductance for CO₂ of 0.0011 with no residual conductance. The status of
# the leaf is not set yet, all are initialised at `0.0`:
LeafModels(energy = Monteith(),
     photosynthesis = Fvcb(),
     stomatal_conductance = ConstantGs(0.0, 0.0011))

# If we need to initialise some variables at different values, we can call the leaf as:

LeafModels(photosynthesis = Fvcb(),Cᵢ = 380.0)

# Or again:
LeafModels(photosynthesis = Fvcb(), energy = Monteith(), Cᵢ = 380.0, Tₗ = 20.0)
```
"""
struct LeafModels{I <: Union{Missing,AbstractInterceptionModel},
            E <: Union{Missing,AbstractEnergyModel},
            A <: Union{Missing,AbstractAModel},
            Gs <: Union{Missing,AbstractGsModel},
            S <: MutableNamedTuple} <: AbstractComponentModel
    interception::I
    energy::E
    photosynthesis::A
    stomatal_conductance::Gs
    status::S
end

function LeafModels(;interception = missing, energy = missing,
                photosynthesis = missing, stomatal_conductance = missing,status...)
    status = init_variables_manual(interception, energy, photosynthesis,
        stomatal_conductance;status...)
    LeafModels(interception,energy,photosynthesis,stomatal_conductance,status)
end

"""
    Component(interception, energy, status)
    Component(;interception = missing, energy = missing, status...)

Generic component, which is a subtype of `AbstractComponentModel` implementing a component with
an interception model and an energy balance model. It can be anything such as a trunk, a
solar panel or else.

# Arguments

- `interception <: Union{Missing,AbstractInterceptionModel}`: An interception model.
- `energy <: Union{Missing,AbstractEnergyModel}`: An energy model.
- `status <: MutableNamedTuple`: a mutable named tuple to track the status (*i.e.* the variables) of
the component. Values are set to `0.0` if not provided as VarArgs (see examples)

# Examples

```julia
# An internode in a plant:
Component(energy = Monteith())
```
"""
struct Component{I <: Union{Missing,AbstractInterceptionModel},
                 E <: Union{Missing,AbstractEnergyModel},
                 S <: MutableNamedTuple} <: AbstractComponentModel
    interception::I
    energy::E
    status::S
end

function Component(;interception = missing, energy = missing,status...)
    status = init_variables_manual(interception, energy;status...)
    Component(interception,energy,status)
end


"""
Atmosphere structure to hold all values related to the meteorology / atmoshpere.

# Arguments

- `T` (°C): air temperature
- `Wind` (m s-1): wind speed
- `P` (kPa): air pressure
- `Rh = rh_from_vpd(VPD,eₛ)` (0-1): relative humidity
- `Cₐ` (ppm): air CO₂ concentration
- `e = vapor_pressure(T,Rh)` (kPa): vapor pressure
- `eₛ = e_sat(T)` (kPa): saturated vapor pressure
- `VPD = eₛ - e` (kPa): vapor pressure deficit
- `ρ = air_density(T, P, constants.Rd, constants.K₀)` (kg m-3): air density
- `λ = latent_heat_vaporization(T, constants.λ₀)` (J kg-1): latent heat of vaporization
- `γ = psychrometer_constant(P, λ, constants.Cₚ, constants.ε)` (kPa K−1): psychrometer "constant"
- `ε = atmosphere_emissivity(T,e,constants.K₀)` (0-1): atmosphere emissivity
- `Δ = e_sat_slope(meteo.T)` (0-1): slope of the saturation vapor pressure at air temperature

# Notes

The structure can be built using only `T`, `Rh`, `Wind` and `P`. All other variables are oprional
and can be automatically computed using the functions given in `Arguments`.

# Examples

```julia
Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
```
"""
Base.@kwdef struct Atmosphere{A}
    T::A
    Wind::A
    P::A
    Rh::A
    Cₐ::A = 400.0
    e::A = vapor_pressure(T,Rh)
    eₛ::A = e_sat(T)
    VPD::A = eₛ - e
    ρ::A = air_density(T, P) # in kg m-3
    λ::A = latent_heat_vaporization(T)
    γ::A = psychrometer_constant(P, λ) # in kPa K−1
    ε::A = atmosphere_emissivity(T,e)
    Δ::A = e_sat_slope(T)
end
