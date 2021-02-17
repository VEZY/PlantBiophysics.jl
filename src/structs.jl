"""
Abstract model type.
All models are subtypes of this one.
"""
abstract type Model end

"""
Assimilation (photosynthesis) abstract model.
If you want to implement your own model, it has to be a subtype
of this one.
"""
abstract type AModel <: Model end

"""
Stomatal conductance abstract model.
If you want to implement you own model, it has to be a subtype
of this one.

A GsModel subtype struct must implement at least a g0 field.

Here is an example of an implementation of a new GsModel subtype with two parameters (g0 and g1):

1. First, define the struct that holds your parameters values:
    ```julia
    struct your_gs_subtype{T} <: GsModel
    g0::T
    g1::T
    end
    ```
2. Define how your stomatal conductance model works by implementing your own version of the
[`gs_closure`](@ref) function:
    ```julia
    function gs_closure(Gs)
        (1.0 + Gs.g1 / sqrt(VPD)) / Cₛ
    end

    function gs(Gs)
        (1.0 + Gs.g1 / sqrt(VPD)) / Cₛ
    end
    ```
3. Instantiate an object of type `your_gs_subtype`:
    ```julia
    Gs = your_gs_subtype(0.03, 0.1)
    ```
4. Call your stomatal model using dispatch on your type:
    ```julia
    gs_mod = gs(Gs)
    ```

Please note that the result of [`gs`](@ref) is just used for the part that modifies the conductance
according to other variables, it is used as:

```julia
Gₛ = Gs.g0 + gs_mod * A
```

Where Gₛ is the stomatal conductance for CO₂ in μmol m-2 s-1, Gs.g0 is the residual conductance, and
A is the carbon assimilation in μmol m-2 s-1.

"""
abstract type GsModel <: Model end

"""
Light interception abstract struct
"""
abstract type InterceptionModel <: Model end


"""
Energy balance abstract struct
"""
abstract type EnergyModel <: Model end


# Scene (the upper one)
abstract type Scene end

# Object
abstract type Object <: Scene end

# Components
abstract type Component <: Object end

# Photosynthetic components
abstract type PhotoComponent <: Component end

# Geometry for the dimensions of components
abstract type GeometryModel <: Model end

"""
    AbstractGeom(d)

The most simple geometry used to represent an abstract leaf, with only one field `d` (m) that
defines the characteristic dimension, *e.g.* the leaf width. It is used to compute the
boundary conductance for heat (see eq. 10.9 from Monteith and Unsworth, 2013).

# Examples

```julia
AbstractGeom(0.03) # A leaf with a width of 3 cm.
```
"""
struct AbstractGeom <: GeometryModel
    d
end

"""
    variables(::Type)
    variables(::Type, vars...)

Returns a tuple with the name of the output variables of a model, or a union of the output
variables for several models.

# Note

Each model can (and should) have a method for this function.

# Examples

```julia
variables(Monteith())

variables(Monteith(), Medlyn(0.03,12.0))
```
"""
function variables(v::T, vars...) where T <: Union{Missing,Model}
    union(variables(v), variables(vars...))
end

"""
    variables(::Missing)

Returns an empty tuple because missing models do not return any variables.
"""
function variables(::Missing)
    ()
end

"""
    variables(::Model)

Returns an empty tuple by default.
"""
function variables(::Model)
    ()
end

"""
    init_variables(vars...)

Intialise model variables based on their instances.

# Examples

```julia
init_variables(Monteith(), Medlyn(0.03,12.0))
```
"""
function init_variables(vars...)
    var_names = variables(vars...)
    MutableNamedTuple(; zip(var_names,fill(zero(Float64),length(var_names)))...)
end


"""
    Status(Tₗ = -999.0, Rn = -999.0, skyFraction = -999.0, PPFD = -999.0, Cₛ = -999.0,
            ψₗ = -999.0, H = -999.0, λE = -999.0, A = -999.0, Gₛ = -999.0, Cᵢ = -999.0,
            Gbₕ = -999.0, Dₗ = -999.0, Rₗₗ = -999.0)

Structure to hold all values related to the status of an object (*e.g.* a [`Leaf`](@ref)). Their
values are often computed by a model.

# Arguments

## Light interception model  (see [`InterceptionModel`](@ref))

- `Rn` (W m-2): net global radiation (PAR + NIR + TIR). Often computed from a light interception model
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

"""
Base.@kwdef mutable struct Status{T}
    Tₗ::T = -999.0
    Rn::T = -999.0
    skyFraction::T = -999.0
    PPFD::T = -999.0
    Cₛ::T = -999.0
    ψₗ::T = -999.0
    H::T = -999.0
    λE::T = -999.0
    A::T = -999.0
    Gₛ::T = -999.0
    Cᵢ::T = -999.0
    Gbₕ::T = -999.0
    Dₗ::T = -999.0
    Rₗₗ::T = -999.0
end

"""
    Leaf{
        geometry <: Union{Missing,GeometryModel},
        interception <: Union{Missing,InterceptionModel},
        energy <: Union{Missing,EnergyModel},
        photosynthesis <: AModel,
        stomatal_conductance <: GsModel,
        status <: MutableNamedTuple
        }

Leaf component, with fields holding model types and parameter values for:

# Arguments

- `geometry <: Union{Missing,GeometryModel}`: A geometry model, e.g. [`AbstractGeom`](@ref).
- `interception <: Union{Missing,InterceptionModel}`: An interception model.
- `energy <: Union{Missing,EnergyModel}`: An energy model, e.g. [`Monteith`](@ref).
- `photosynthesis <: AModel`: A photosynthesis model, e.g. [`Fvcb`](@ref)
- `stomatal_conductance <: GsModel`: A stomatal conductance model, e.g. [`Medlyn`](@ref) or
[`ConstantGs`](@ref)
- `status <: MutableNamedTuple`: a mutable struct to track the status (*i.e.* the variables) of
the leaf. The default values are found using [`init_variables`](@ref).

# Details

The status field depends on the input models, but generally the variables are:

## Light interception model  (see [`InterceptionModel`](@ref))

- `Rn` (W m-2): net global radiation (PAR + NIR + TIR). Often computed from a light interception model
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
# the leaf is not set yet (`init_variables()` is called under the hood):

Leaf(geometry = AbstractGeom(0.03),
     energy = Monteith(),
     photosynthesis = Fvcb(),
     stomatal_conductance = ConstantGs(0.0, 0.0011))
```
"""
Base.@kwdef struct Leaf{G <: Union{Missing,GeometryModel},
                        I <: Union{Missing,InterceptionModel},
                        E <: Union{Missing,EnergyModel},
                        A <: AModel,
                        Gs <: GsModel,
                        S <: MutableNamedTuple} <: PhotoComponent
    geometry::G = missing
    interception::I = missing
    energy::E = missing
    photosynthesis::A
    stomatal_conductance::Gs
    status::S = init_variables(geometry,interception,energy,photosynthesis,stomatal_conductance)
end



"""
Metamer component, with one field holding the light interception model type and its parameter values.
"""
Base.@kwdef struct Metamer{I<: Union{Missing,InterceptionModel}} <: Component
    interception::I = missing
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
Base.@kwdef struct Atmosphere{A} <: Scene
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
