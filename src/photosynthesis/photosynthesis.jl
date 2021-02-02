"""
    photosynthesis(leaf::PhotoOrgan; Tₗ = missing, PPFD = missing, Rh = missing,
                    Cₐ = missing, Cₛ = missing, VPD = missing, ψₗ = missing,
                    constants = Constants())

Generic photosynthesis model for photosynthetic organs. Computes the assimilation and
stomatal conductance.

The models used are defined by the types of the `Photosynthesis` and `StomatalConductance`
fields of the `leaf`. For exemple to use the implementation of the Farquhar–von Caemmerer–Berry
(FvCB) model (see [`assimilation`](@ref)), the `leaf.Photosynthesis` field should be of type
[`Fvcb`](@ref).

Keyword arguments also depend on the models used (see below).

### Photosynthesis:

- Fvcb:
    - Cₛ (ppm): stomatal CO₂ concentration
    - PPFD (μmol m-2 s-1): absorbed Photosynthetic Photon Flux Density
    - Tₗ (°C): leaf temperature
- FvcbIter:
    - Cₐ (ppm): atmospheric CO₂ concentration
    - PPFD (μmol m-2 s-1): absorbed Photosynthetic Photon Flux Density
    - Tₗ (°C): leaf temperature
    - Gbc (mol m-2 s-1): boundary layer conductance for CO₂

### Stomatal conductance

- Medlyn:
    - VPD (kPa): vapor pressure deficit of the air


# Examples

```julia
# Using Fvcb:
leaf = Leaf(;Photosynthesis = Fvcb(), StomatalConductance = Medlyn(0.03, 12.0))
photosynthesis(leaf, Tₗ = 25.0, PPFD = 1000.0, Cₛ = 400.0, VPD = 2.0)

# Using FvcbIter:
leaf = Leaf(;Photosynthesis = FvcbIter(), StomatalConductance = Medlyn(0.03, 12.0))
photosynthesis(leaf, Tₗ = 25.0, PPFD = 1000.0, Gbc = 1.0, VPD = 2.0, Cₐ = 400.0)

```
"""
function photosynthesis(leaf::PhotoOrgan; Tₗ, PPFD,
                        Cₐ = missing, Rh = missing,
                        Gbc = missing, Cₛ = 0.0, VPD = missing, ψₗ = missing,
                        constants = Constants())
    environment = MutableNamedTuple(Tₗ = Tₗ, PPFD = PPFD, Cₐ = Cₐ, Rh = Rh, Gbc = Gbc,
                                    Cₛ = Cₛ, VPD = VPD, ψₗ = ψₗ)
    assimilation(leaf.Photosynthesis, leaf.StomatalConductance,environment,constants)
end
