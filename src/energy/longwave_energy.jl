"""
    black_body(T, K₀, σ)
    black_body(T)

Thermal infrared, *i.e.* longwave radiation emitted from a black body at temperature T.

- `T`: temperature of the object in Celsius degree
- `K₀`: absolute zero (°C)
- `σ` (``W\\ m^{-2}\\ K^{-4}``) [Stefan-Boltzmann constant](https://en.wikipedia.org/wiki/Stefan%E2%80%93Boltzmann_law)

# Note

`K₀` and `σ` are taken from [`Constants`](@ref) if not provided.

"""
function black_body(T, K₀, σ)
  Tₖ = T - K₀
  σ * (Tₖ^4.0)
end

function black_body(T)
    constants = Constants()
    black_body(T, constants.K₀, constants.σ)
end


"""
Thermal infrared, *i.e.* longwave radiation emitted from an object at temperature T.

- `T`: temperature of the object in Celsius degree
- `ε` object [emissivity](https://en.wikipedia.org/wiki/Emissivity) (not to confuse with ε the
ratio of molecular weights from [`Constants`](@ref)). A typical value for a leaf is 0.955.
- `K₀`: absolute zero (°C)
- `σ` (``W\\ m^{-2}\\ K^{-4}``) [Stefan-Boltzmann constant](https://en.wikipedia.org/wiki/Stefan%E2%80%93Boltzmann_law)

# Note

`K₀` and `σ` are taken from [`Constants`](@ref) if not provided.

# Examples

```julia
# Thermal infrared radiation of water at 25 °C:
grey_body(25.0, 0.96)
```
"""
function grey_body(T, ε, K₀, σ)
  ε * black_body(T, K₀, σ)
end

function grey_body(T, ε)
    constants = Constants()
    grey_body(T, ε, constants.K₀, constants.σ)
end


"""
    net_longwave_radiation(T₁,T₂,ε₁,ε₂,F₁,K₀,σ)
    net_longwave_radiation(T₁,T₂,ε₁,ε₂,F₁)

Net longwave radiation fluxes (*i.e.* thermal radiation, W m-2) between an object and another.
The object of interest is at temperature T₁ and has an emissivity ε₁, and the object with
wich it exchanges energy is at temperature T₂ and has an emissivity ε₂.

If the result is positive, then the object of interest gain energy.

# Arguments

- `T₁` (Celsius degree): temperature of the target object (object 1)
- `T₂` (Celsius degree): temperature of the object with which there is potential exchange (object 2)
- `ε₁`: object 1 emissivity
- `ε₂`: object 2 emissivity
- `F₁`: view factor (0-1), *i.e.* visible fraction of object 2 from object 1 (see note)
- `K₀`: absolute zero (°C)
- `σ` (``W\\ m^{-2}\\ K^{-4}``) [Stefan-Boltzmann constant](https://en.wikipedia.org/wiki/Stefan%E2%80%93Boltzmann_law)

# Note

`F₁`, the view factor (also called shape factor) is a coefficient applied to the semi-hemisphere
field of view of object 1 that "sees" object 2. E.g. a leaf can be viewed as a plane. If one side
of the leaf sees only object 2 in its field of view (e.g. the sky), then `F₁ = 1`.
Then the net longwave radiation flux for this part of the leaf is multiplied by its actual
surface to get the exchange. Note that we apply reciprocity between the two objects for
the view factor (they have the same value), *i.e.*: A₁F₁₂ = A₂F₂₁.

Then, if we take a leaf as object 1, and the sky as object 2, the visible fraction of
sky viewed by the leaf would be:

- `0.5` if the leaf is on top of the canopy, *i.e.* the upper side of the leaf sees the sky,
the side below sees other leaves and the soil.
- between 0 and 0.5 if it is within the canopy and partly shaded by other objects.

Note that `A₁` for a leaf is twice its common used leaf area, because `A₁` is the **total**
leaf area of the object that exchange energy.

```julia
# Net thermal radiation fluxes between a leaf and the sky considering the leaf at the top of
# the canopy:
Tₗ = 25.0 ; Tₐ = 20.0
ε₁ = 0.955 ; ε₂ = 1.0
Rₗₗ = net_longwave_radiation(Tₗ,Tₐ,ε₁,ε₂,1.0)
Rₗₗ

# Rₗₗ is the net longwave radiation flux between the leaf and the atmosphere per surface area.
# To get the actual net longwave radiation flux we need to multiply by the surface of the
# leaf, e.g. for a leaf of 2cm²:
leaf_area = 2e-4 # in m²
Rₗₗ * leaf_area

# The leaf lose ~0.0055 W towards the atmosphere.
```

# References

Cengel, Y, et Transfer Mass Heat. 2003. A practical approach. New York, NY, USA: McGraw-Hill.
"""
function net_longwave_radiation(T₁,T₂,ε₁,ε₂,F₁,K₀,σ)
    (black_body(T₁,K₀,σ) - black_body(T₂,K₀,σ)) / (1.0 / ε₁ + 1.0/ε₂ - 1.0) * F₁
end

function net_longwave_radiation(T₁,T₂,ε₁,ε₂,F₁)
    constants = Constants()
    net_longwave_radiation(T₁,T₂,ε₁,ε₂,F₁,constants.K₀,constants.σ)
end

"""
    atmosphere_emissivity(Tₐ,eₐ)

Emissivity of the atmoshpere at a given temperature and vapor pressure.

# Arguments

- `Tₐ` (°C): air temperature
- `eₐ` (kPa): air vapor pressure
- `K₀` (°C): absolute zero

# Examples

```julia
Tₐ = 20.0
VPD = 1.5
atmosphere_emissivity(Tₐ, e(Tₐ,VPD))
```

# References

Leuning, R., F. M. Kelliher, DGG de Pury, et E.-D. SCHULZE. 1995. « Leaf nitrogen,
photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant,
Cell & Environment 18 (10): 1183‑1200.
"""
function atmosphere_emissivity(Tₐ,eₐ,K₀)
    0.642 * (eₐ * 100 / (Tₐ - K₀))^(1 / 7)
end

function atmosphere_emissivity(Tₐ,eₐ)
    atmosphere_emissivity(Tₐ,eₐ,Constants().K₀)
end
