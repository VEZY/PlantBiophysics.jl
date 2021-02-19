"""
struct to hold the parameters for Medlyn et al. (2011) stomatal
conductance model for CO₂ .

Then used for example as follows:
Gs = Medlyn(0.03,0.1)
gs_mod = gs(Gs,(Cₛ = 400.0, VPD = 1.5))
Gₛ = Gs.g0 + gs_mod * A

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.

"""
Base.@kwdef struct Medlyn{T} <: AbstractGsModel
 g0::T
 g1::T
end

function variables(::Medlyn)
    (:Dₗ,:Cₛ,:A)
end

"""
    gs_closure(leaf::Leaf{G,I,E,A,<:Medlyn,S},meteo)

Stomatal closure for CO₂ according to Medlyn et al. (2011). Carefull, this is just a part of
the computation of the stomatal conductance.

The result of this function is then used as:

    gs_mod = gs_closure(leaf,meteo)

    # And then stomatal conductance (μmol m-2 s-1) calling [`gs`](@ref):
    Gₛ = leaf.stomatal_conductance.g0 + gs_mod * leaf.status.A

# Arguments

- `leaf::Leaf{.,.,.,<:Fvcb,<:AbstractGsModel,.}`: A [`Leaf`](@ref) struct holding the parameters for
the model.
- `meteo`: meteorology structure, see [`Atmosphere`](@ref). Is not used in this model.

# Examples

```julia
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = Leaf(photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            Cₛ = 380.0, Dₗ = meteo.VPD)


gs_mod = gs_closure(leaf, meteo)

A = 20 # example assimilation (μmol m-2 s-1)
Gs = leaf.stomatal_conductance.g0 + gs_mod * A
```

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.
"""
function gs_closure(leaf::Leaf{G,I,E,A,<:Medlyn,S},meteo) where {G,I,E,A,S}
    (1.0 + leaf.stomatal_conductance.g1 / sqrt(leaf.status.Dₗ)) / leaf.status.Cₛ
end


"""
    gs(leaf::Leaf{G,I,E,A,<:Medlyn,S},gs_mod)
    gs(leaf::Leaf{G,I,E,A,<:Medlyn,S},meteo<:Atmosphere)

Stomatal conductance for CO₂ (mol m-2 s-1) according to Medlyn et al. (2011).

# Arguments

- `leaf::Leaf{G,I,E,A,<:Medlyn,S}`: A leaf struct holding the parameters for the model. See
[`Leaf`](@ref), and [`Medlyn`](@ref) or [`ConstantGs`](@ref) for the conductance models.
- `gs_mod`: the output from [`gs_closure`](@ref)
- `meteo<:Atmosphere`: meteo data, see [`Atmosphere`](@ref)

# Examples

```julia
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

# Using a constant value for Gs:

leaf = Leaf(photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03,0.1), # Instance of a Medlyn type
            A = 20.0, Cₛ = 380.0, Dₗ = meteo.VPD)

# Computing the stomatal conductance using the Medlyn et al. (2011) model:
gs(leaf,meteo)
```

# References

Medlyn, Belinda E., Remko A. Duursma, Derek Eamus, David S. Ellsworth, I. Colin Prentice,
Craig V. M. Barton, Kristine Y. Crous, Paolo De Angelis, Michael Freeman, et Lisa Wingate.
2011. « Reconciling the optimal and empirical approaches to modelling stomatal conductance ».
Global Change Biology 17 (6): 2134‑44. https://doi.org/10.1111/j.1365-2486.2010.02375.x.
```
"""
function gs(leaf::Leaf{G,I,E,A,<:Medlyn,S},gs_mod) where {G,I,E,A,S}
    leaf.stomatal_conductance.g0 + gs_mod * leaf.status.A
end

function gs(leaf::Leaf{G,I,E,A,<:Medlyn,S},meteo::M) where {G,I,E,A,S,M<:Atmosphere}
    leaf.stomatal_conductance.g0 + gs_closure(leaf,meteo) * leaf.status.A
end
