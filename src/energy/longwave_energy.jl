
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
    Tₖ = T - constants.K₀
    ε * black_body(T, constants.K₀, constants.σ)
end

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
    Tₖ = T - constants.K₀
    constants.σ * (Tₖ^4.0)
end



"""
    net_longwave_radiation(T₁,T₂,ε₁,ε₂,sky_fraction,K₀,σ)
    net_longwave_radiation(T₁,T₂,ε₁,ε₂,visible_fraction)

Net longwave radiation fluxes (*i.e.* thermal radiation, W m-2) between an object and another.
The object of interest is at temperature T₁ and has an emissivity ε₁, and the object with
wich it exchanges energy is at temperature T₂ and has an emissivity ε₂.

If the result is positive, then the object of interest gain energy.

# Arguments

- `T₁` (Celsius degree): temperature of the target object (object 1)
- `T₂` (Celsius degree): temperature of the object with which there is potential exchange (object 2)
- `ε₁`: object 1 emissivity
- `ε₂`: object 2 emissivity
- `visible_fraction`: visible fraction of object 2 from object 1 (see note)
- `K₀`: absolute zero (°C)
- `σ` (``W\\ m^{-2}\\ K^{-4}``) [Stefan-Boltzmann constant](https://en.wikipedia.org/wiki/Stefan%E2%80%93Boltzmann_law)

# Note

For example,
If we take a leaf as object 1, and the sky as object 2, the visible fraction of sky viewed by
the leaf would be:

- `2` if the leaf view only sky on every directions, *e.g.* in a controlled chamber with only the
leaf and same material all around (exchanges on two faces),
- `1` if the leaf is on top of the canopy, *i.e.* the upper side of the leaf sees the sky,
the side below sees other leaves and the soil.
- between 0 and 1 if it is within the canopy and partly shaded by other objects.

```julia
# Net thermal radiation fluxes between a leaf and the sky considering the leaf at the top of
# the canopy:
Tₗ = 25.0 ; Tₐ = 20.0
ε₁ = 0.955 ; ε₂ = 1.0
net_longwave_radiation(Tₗ,Tₐ,ε₁,ε₂,1.0)
```
"""
function net_longwave_radiation(T₁,T₂,ε₁,ε₂,visible_fraction,K₀,σ)
    (grey_body(T₂,ε₂,K₀,σ) - grey_body(T₁,ε₁,K₀,σ)) * visible_fraction
end

function net_longwave_radiation(T₁,T₂,ε₁,ε₂,visible_fraction)
    constants = Constants()
     (grey_body(T₂,ε₂,constants.K₀,constants.σ) -
        grey_body(T₁,ε₁,constants.K₀,constants.σ)) * visible_fraction
end
