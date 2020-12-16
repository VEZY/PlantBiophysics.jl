abstract type Model end

"""
Assimilation (photosynthesis) abstract model
"""
abstract type AModel <: Model end


"""
Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980;
von Caemmerer and Farquhar, 1981).

The definition:

- `Tᵣ`: the reference temperature (°C) at which other parameters were measured
- `VcMaxRef`: maximum rate of Rubisco activity (``μmol\\ m^{-2}\\ s^{-1}``)
- `JMaxRef`: potential rate of electron transport (``μmol\\ m^{-2}\\ s^{-1}``)
- `RdRef`: mitochondrial respiration in the light at reference temperature (``μmol\\ m^{-2}\\ s^{-1}``)
- `Eₐᵣ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise for Rd.
- `O₂`: intercellular dioxygen concentration (``ppm``)
- `Eₐⱼ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise for JMax.
- `Hdⱼ`: rate of decrease of the function above the optimum (also called EDVJ) for JMax.
- `Δₛⱼ`: entropy factor for JMax.
- `Eₐᵥ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise for VcMax.
- `Hdᵥ`: rate of decrease of the function above the optimum (also called EDVC) for VcMax.
- `Δₛᵥ`: entropy factor for VcMax.

The default values of the temperature correction parameters are taken from
[plantecophys](https://remkoduursma.github.io/plantecophys/). If there is no negative effect
of high temperatures on the reaction (Jmax or VcMax), then Δₛ can be set to 0.0.

# See also


# References

Caemmerer, S. von, et G. D. Farquhar. 1981. « Some Relationships between the Biochemistry of
Photosynthesis and the Gas Exchange of Leaves ». Planta 153 (4): 376‑87.
https://doi.org/10.1007/BF00384257.

Farquhar, G. D., S. von von Caemmerer, et J. A. Berry. 1980. « A biochemical model of
photosynthetic CO2 assimilation in leaves of C3 species ». Planta 149 (1): 78‑90.

# Examples

```julia
Get the fieldnames:
fieldnames(Fvcb)
# Using default values for the model:
A = Fvcb()

A.Eₐᵥ
```
"""
Base.@kwdef struct Fvcb{T} <: AModel
    Tᵣ::T = 25.0
    VcMaxRef::T = 200.0
    JMaxRef::T = 250.0
    RdRef::T = 0.6
    Eₐᵣ::T = 46390.0
    O₂::T = 210.0
    Eₐⱼ::T = 29680.0
    Hdⱼ::T = 200000.0
    Δₛⱼ::T = 631.88
    Eₐᵥ::T = 58550.0
    Hdᵥ::T = 200000.0
    Δₛᵥ::T = 629.26
end

abstract type GsModel <: Model end

struct Medlyn{T} <: GsModel
 g0::T
 g1::T
end

# Organs
abstract type Organ end

abstract type PhotoOrgan <: Organ end

mutable struct Leaf{A,Gs} <: PhotoOrgan
    assimilation::A
    conductance::Gs
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
