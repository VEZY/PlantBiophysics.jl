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
abstract type GeometryModel end

struct AbstractGeom
    d
end

"""
Leaf component, with fields holding model types and parameter values for:

- geometry:
- interception
- energy
- photosynthesis
- stomatal_conductance
- status:
    - `Tₗ = missing` (°C): temperature of the object
    - `Rₗₗ = missing` (W m-2): net longwave radiation for the object (TIR)
    - `Gbₕ = missing` (m s-1): boundary conductance for heat (free + forced convection)
    - `λE = missing` (W m-2): latent heat flux
    - `H = missing` (W m-2): sensible heat flux
    - `Dₗ = missing` (kPa): vapour pressure difference between the surface and the saturation
    vapour pressure, also called air-to-leaf VPD
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
    status::S = MutableNamedTuple(Tₗ = -999.0, Rn = -999.0, Rₗₗ = -999.0, PPFD = -999.0,
                                    Cₛ = -999.0, ψₗ = -999.0, H = -999.0, λE = -999.0,
                                    A = -999.0, Gₛ = -999.0, Cᵢ = -999.0, Gbₕ = -999.0,
                                    Dₗ = -999.0)
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
- `Rh = rh_from_vpd(VPD,eₛ)` (0-1): relative humidity
- `Wind` (m s-1): wind speed
- `P` (kPa): air pressure
- `e = vapor_pressure(T,Rh)` (kPa): vapor pressure
- `eₛ = e_sat(T)` (kPa): saturated vapor pressure
- `VPD = eₛ - e` (kPa): vapor pressure deficit
- `ρ = air_density(T, P, constants.Rd, constants.K₀)` (kg m-3): air density
- `λ = latent_heat_vaporization(T, constants.λ₀)` (J kg-1): latent heat of vaporization
- `γ = psychrometer_constant(P, λ, constants.Cₚ, constants.ε)` (kPa K−1): psychrometer "constant"
- `ε = atmosphere_emissivity(T,e,constants.K₀)` (0-1): atmosphere emissivity

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
    e::A = vapor_pressure(T,Rh)
    eₛ::A = e_sat(T)
    VPD::A = eₛ - e
    ρ::A = air_density(T, P) # in kg m-3
    λ::A = latent_heat_vaporization(T)
    γ::A = psychrometer_constant(P, λ) # in kPa K−1
    ε::A = atmosphere_emissivity(T,e)
end
