abstract type Model end

"""
Assimilation (photosynthesis) abstract model
"""
abstract type AModel <: Model end


"""
Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980;
von Caemmerer and Farquhar, 1981).

The definition and default values are:

- `Tᵣ`: the reference temperature (°C) at which other parameters were measured
- `VcMaxRef`: maximum rate of Rubisco activity (``μmol\\ m^{-2}\\ s^{-1}``)
- `JMaxRef`: potential rate of electron transport (``μmol\\ m^{-2}\\ s^{-1}``)
- `Rd`: mitochondrial respiration in the light at reference temperature (``μmol\\ m^{-2}\\ s^{-1}``)
- `O₂`: intercellular dioxygen concentration (``ppm``)
- `Eₐⱼ`: activation energy (``J\\ mol^{-1}``), or the exponential rate of rise. Default value from
[plantecophys](https://remkoduursma.github.io/plantecophys/). Should be
- `Hd`: rate of decrease of the function above the optimum (called EDVJ in
[MAESPA](http://maespa.github.io/) and [plantecophys](https://remkoduursma.github.io/plantecophys/)).
Default value from [plantecophys](https://remkoduursma.github.io/plantecophys/)
- `Δₛⱼ`: entropy factor. Default value from [plantecophys](https://remkoduursma.github.io/plantecophys/)

"""
Base.@kwdef struct Fvcb{T where T} <: AModel
    Tᵣ::T = 25.0
    VcMaxRef::T = 200.0
    JMaxRef::T = 250.0
    Rd::T = 0.6
    O₂::T = 210.0
    Eₐᵥ::T = 58550.0
    Eₐⱼ::T = 39676.89
    Hd::T = 200000.0
    Δₛⱼ::T = 641.3615
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
