
"""
Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980;
von Caemmerer and Farquhar, 1981).

Iterative implementation, i.e. the assimilation is computed iteratively over Cᵢ.

For more details on arguments, see [`Fvcb`](@ref).
This structure has several more parameters:

- `iter_A_max::Int`: maximum number of iterations allowed for the iteration on the
assimilation.
- `ϵ_A::T = 1`: threshold below which the assimilation is considered constant. Given in
percent of change, *i.e.* 1% means that two successive assimilations with less than 1%
difference in value are considered the same value.
"""
Base.@kwdef struct FvcbIter{T} <: AModel
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
    α::T = 0.425
    θ::T = 0.90
    iter_A_max::Int = 20
    ϵ_A::T = 1.0
end

"""
    assimiliation(A_mod::FvcbIter,Gs_mod::GsModel,environment::MutableNamedTuple,constants)

Photosynthesis using the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis
 (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981).
Computation is made following Farquhar & Wong (1984), Leuning et al. (1995), and the
Archimed model.

Iterative implementation, i.e. the assimilation is computed iteratively over Cᵢ. For the
analytical resolution, see [Fvcb](@ref).

# Returns

A tuple with (A, Gₛ, Cᵢ):

- A: carbon assimilation (μmol m-2 s-1)
- Gₛ: stomatal conductance (mol m-2 s-1)
- Cᵢ: intercellular CO₂ concentration (ppm)

# Arguments

- `A_mod::FvcbIter`: The struct holding the parameters for the model. See [`FvcbIter`](@ref).
- `Gs_mod::GsModel`: The struct holding the parameters for the stomatal conductance model. See
[`Medlyn`](@ref) or [`ConstantGs`](@ref).
- `environment::MutableNamedTuple`: the values for the variables:
    - Tₗ (°C): leaf temperature
    - PPFD (μmol m-2 s-1): absorbed Photosynthetic Photon Flux Density
    - gbc (mol m-2 s-1): boundary layer conductance for CO₂
    - Rh (0-1): air relative humidity
    - Cₐ (ppm): stomatal CO₂ concentration
    - VPD (kPa): vapor pressure deficit of the air
    - ψₗ (kPa): leaf water potential

# Note

The mandatory variables provided in `environment` are Tₗ, PPFD, and Cₐ. Others are optional depending
on the stomatal conductance model. For example VPD is needed for the Medlyn et al. (2011) model.

# Examples

```julia
assimiliation(FvcbIter(),
              Gs(),
              (Tₗ = 25.0, PPFD = 1000.0, Rh = missing, Cₛ = 300.0, VPD = 2.0,
                ψₗ = missing),
             constants)
```

# References

Baldocchi, Dennis. 1994. « An analytical solution for coupled leaf photosynthesis and
stomatal conductance models ». Tree Physiology 14 (7-8‑9): 1069‑79.
https://doi.org/10.1093/treephys/14.7-8-9.1069.

Farquhar, G. D., S. von von Caemmerer, et J. A. Berry. 1980. « A biochemical model of
photosynthetic CO2 assimilation in leaves of C3 species ». Planta 149 (1): 78‑90.

Leuning, R., F. M. Kelliher, DGG de Pury, et E.D. Schulze. 1995. « Leaf nitrogen,
photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant,
Cell & Environment 18 (10): 1183‑1200.
"""
function assimiliation(A_mod::FvcbIter,Gs_mod::GsModel,environment::MutableNamedTuple,
                        constants)

    # Instantiate an Fvcb struct
    A_Fvcb = Fvcb(A_mod.Tᵣ,A_mod.VcMaxRef,A_mod.JMaxRef,A_mod.RdRef,A_mod.Eₐᵣ,
                    A_mod.O₂,A_mod.Eₐⱼ,A_mod.Hdⱼ,A_mod.Δₛⱼ,A_mod.Eₐᵥ,A_mod.Hdᵥ,
                    A_mod.Δₛᵥ,A_mod.α,A_mod.θ)

    # Start with a probable value (Cₛ = Cₐ):
    environment.Cₛ = environment.Cₐ

    # First simulation with this value (Cₛ = Cₐ):
    A_prev, Gₛ, Cᵢ  = assimiliation(A_mod::Fvcb,Gs_mod::GsModel,environment,constants)
    iter = true

    while iter

        A, Gₛ, Cᵢ = assimiliation(A_mod::Fvcb,Gs_mod::GsModel,environment,constants)

        if abs(A-A_old)/A_old <= A_mod.ϵ_A || iter_max == A_mod.iter_A_max
            iter = false
        end

        environment.Cₛ = min(environment.Cₐ, environment.Cₐ - A * 1.0e-6 / environment.Gbc)

        iter_max += 1
    end

    return (A, Gₛ, Cᵢ)
end


"""
Photosynthesis using the iterative Farquhar–von Caemmerer–Berry (FvCB) model with
default constant values (found in [`Constants`](@ref)).
"""
function assimiliation(A_mod::FvcbIter,Gs_mod::GsModel,environment::MutableNamedTuple)
    assimiliation(A_mod,Gs_mod,environment,Constants())
end

"""
    assimiliation(A_mod::FvcbIter, Gs_mod::GsModel; Tₗ = missing, PPFD = missing, Rh = missing,
                    Cₛ = missing, VPD = missing, ψₗ = missing)

Photosynthesis using the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis
 (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981).

Iterative implementation, i.e. the assimilation is computed iteratively over Cᵢ. For the
analytical resolution, see [Fvcb](@ref).

# Returns

A tuple with (A, Gₛ, Cᵢ):

- A: carbon assimilation (μmol m-2 s-1)
- Gₛ: stomatal conductance (mol m-2 s-1)
- Cᵢ: intercellular CO₂ concentration (ppm)

# Arguments

- `A_mod::FvcbIter`: The struct holding the parameters for the model. See [`FvcbIter`](@ref).
- `Gs_mod::GsModel`: The struct holding the parameters for the stomatal conductance model. See
[`Medlyn`](@ref) or [`ConstantGs`](@ref).
- Tₗ (°C): air temperature
- PPFD (μmol m-2 s-1): absorbed Photosynthetic Photon Flux Density
- gbc (mol m-2 s-1): boundary layer conductance for CO₂
- Rh (0-1): air relative humidity
- Cₐ (ppm): air CO₂ concentration
- VPD (kPa): vapor pressure deficit of the air
- ψₗ (kPa): leaf water potential

# Note

The mandatory inputs to provide are: A_mod, Gs_mod, Tₗ, PPFD, and Cₛ. Others are optional depending
on the stomatal conductance model. For example VPD is needed for the Medlyn et al. (2011) model.
Please note the optional inputs are keyword parameters, so they must be explicitely named.

# Examples

```julia
assimiliation(FvcbIter(),Gs(),
              Tₗ = 25.0, PPFD = 1000.0, gbc = 1.0, Cₐ = 400.0, VPD = 2.0)
              )
```

# References

Farquhar, G. D., S. von von Caemmerer, et J. A. Berry. 1980. « A biochemical model of
photosynthetic CO2 assimilation in leaves of C3 species ». Planta 149 (1): 78‑90.
"""
function assimiliation(A_mod::FvcbIter, Gs_mod::GsModel; Tₗ = missing, PPFD = missing, Rh = missing,
                        Cₛ = missing, VPD = missing, ψₗ = missing)
    environment = MutableNamedTuple(Tₗ = Tₗ, PPFD = PPFD, gbc = gbc, Cₐ = Cₐ, VPD = VPD, ψₗ = ψₗ)
    assimiliation(A_mod,Gs_mod,environment,Constants())
end
