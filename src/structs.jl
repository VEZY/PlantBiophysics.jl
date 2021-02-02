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
Gs = your_gs_subtype(0.03, 0.1)

4. Call your stomatal model using dispatch on your type:
gs_mod = gs(Gs)

Please note that the result of [`gs`](@ref) is just used for the part that modifies the conductance
according to other variables, it is used as:

Gₛ = Gs.g0 + gs_mod * A

Where Gₛ is the stomatal conductance for CO₂ in μmol m-2 s-1, Gs.g0 is the residual conductance, and
A is the carbon assimilation in μmol m-2 s-1.

"""
abstract type GsModel <: Model end

"""
Light interception abstract struct
"""
abstract type InterceptionModel <: Model end

# Organs
abstract type Organ end

# Photosynthetic organs
abstract type PhotoOrgan <: Organ end


"""
Leaf organ, with three fields holding model types and parameter values for:

 - Interception
 - Photosynthesis
 - StomatalConductance
"""
Base.@kwdef struct Leaf{I<: Union{Missing,InterceptionModel}, A<: AModel, Gs <: GsModel} <: PhotoOrgan
    Interception::I = missing
    Photosynthesis::A
    StomatalConductance::Gs
end

"""
Metamer organ, with one field holding the light interception model type and its parameter values.
"""
Base.@kwdef struct Metamer{I<: Union{Missing,InterceptionModel}} <: Organ
    Interception::I = missing
end


"""
Physical constants

The definition and default values are:

- `K₀ = -273.15`: absolute zero (°C)
- `R = 8.314`: universal gas constant (``J\\ mol^{-1}\\ K^{-1}``).

"""
Base.@kwdef struct Constants
    K₀::Float64 = -273.15
    R::Float64 = 8.314
end
