"""
Struct to hold parameter and values for the energy model close to the one in
Monteith and Unsworth (2013)

# Arguments

- `aₛₕ = 2`: number of faces of the object that exchange sensible heat fluxes
- `aₛᵥ = 1`: number of faces of the object that exchange latent heat fluxes (hypostomatous => 1)
- `ε = 0.955`: emissivity of the object
- `maxiter = 10`: maximal number of iterations allowed to close the energy balance
- `ΔT = 0.01` (°C): maximum difference in object temperature between two iterations to consider convergence

# Examples

```julia
energy_model = Monteith() # a leaf in an illuminated chamber
```
"""
struct Monteith{T,S} <: AbstractEnergy_BalanceModel
    aₛₕ::S
    aₛᵥ::S
    ε::T
    maxiter::S
    ΔT::T
end

function Monteith(; aₛₕ=2, aₛᵥ=1, ε=0.955, maxiter=10, ΔT=0.01)
    param_int = promote(aₛₕ, aₛᵥ, maxiter)
    param_float = promote(ε, ΔT)
    Monteith(param_int[1], param_int[2], param_float[1], param_int[3], param_float[2])
end

function PlantSimEngine.inputs_(::Monteith)
    (Rₛ=-Inf, sky_fraction=-Inf, d=-Inf)
end

function PlantSimEngine.outputs_(::Monteith)
    (
        Tₗ=-Inf, Rn=-Inf, Rₗₗ=-Inf, H=-Inf, λE=-Inf, Cₛ=-Inf, Cᵢ=-Inf,
        A=-Inf, Gₛ=-Inf, Gbₕ=-Inf, Dₗ=-Inf, Gbc=-Inf, iter=typemin(Int)
    )
end

Base.eltype(x::Monteith) = typeof(x).parameters[1]

PlantSimEngine.dep(::Monteith) = (photosynthesis=AbstractPhotosynthesisModel,)

"""
    energy_balance!_(::Monteith, models, status, meteo, constants=Constants())

Leaf energy balance according to Monteith and Unsworth (2013), and corrigendum from
Schymanski et al. (2017). The computation is close to the one from the MAESPA model (Duursma
et al., 2012, Vezy et al., 2018) here. The leaf temperature is computed iteratively to close
the energy balance using the mass flux (~ Rn - λE).

# Arguments

- `::Monteith`: a Monteith model, usually from a model list (*i.e.* m.energy_balance)
- `models`: A `ModelList` struct holding the parameters for the model with
initialisations for:
    - `Rₛ` (W m-2): net shortwave radiation (PAR + NIR). Often computed from a light interception model
    - `sky_fraction` (0-2): view factor between the object and the sky for both faces (see details).
    - `d` (m): characteristic dimension, *e.g.* leaf width (see eq. 10.9 from Monteith and Unsworth, 2013).
- `status`: the status of the model, usually the model list status (*i.e.* leaf.status)
- `meteo`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

# Details

The sky_fraction in the variables is equal to 2 if all the leaf is viewing is sky (e.g. in a
controlled chamber), 1 if the leaf is *e.g.* up on the canopy where the upper side of the
leaf sees the sky, and the side bellow sees soil + other leaves that are all considered at
the same temperature than the leaf, or less than 1 if it is partly shaded.

# Notes

If you want the algorithm to print a message whenever it does not reach convergence, use the
debugging mode by executing this in the REPL: `ENV["JULIA_DEBUG"] = PlantBiophysics`.

More information [here](https://docs.julialang.org/en/v1/stdlib/Logging/#Environment-variables).

# Examples

```julia
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

# Using a constant value for Gs:
leaf = ModelList(
    energy_balance = Monteith(),
    photosynthesis = Fvcb(),
    stomatal_conductance = ConstantGs(0.0, 0.0011),
    status = (Rₛ = 13.747, sky_fraction = 1.0, d = 0.03)
)

energy_balance!(leaf,meteo)
leaf.status.Rn
julia> 12.902547446281233

# Using the model from Medlyn et al. (2011) for Gs:
leaf = ModelList(
    energy_balance = Monteith(),
    photosynthesis = Fvcb(),
    stomatal_conductance = Medlyn(0.03, 12.0),
    status = (Rₛ = 13.747, sky_fraction = 1.0, PPFD = 1500.0, d = 0.03)
)

energy_balance!(leaf,meteo)
leaf[:Rn]
leaf[:Rₗₗ]
leaf[:A]

DataFrame(leaf)
```

# References

Duursma, R. A., et B. E. Medlyn. 2012. « MAESPA: a model to study interactions between water
limitation, environmental drivers and vegetation function at tree and stand levels, with an
example application to [CO2] × drought interactions ». Geoscientific Model Development 5 (4):
919‑40. https://doi.org/10.5194/gmd-5-919-2012.

Monteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i)
Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition),
edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.

Schymanski, Stanislaus J., et Dani Or. 2017. « Leaf-Scale Experiments Reveal an Important
Omission in the Penman–Monteith Equation ». Hydrology and Earth System Sciences 21 (2): 685‑706.
https://doi.org/10.5194/hess-21-685-2017.

Vezy, Rémi, Mathias Christina, Olivier Roupsard, Yann Nouvellon, Remko Duursma, Belinda Medlyn,
Maxime Soma, et al. 2018. « Measuring and modelling energy partitioning in canopies of varying
complexity using MAESPA model ». Agricultural and Forest Meteorology 253‑254 (printemps): 203‑17.
https://doi.org/10.1016/j.agrformet.2018.02.005.
"""
function energy_balance!_(::Monteith, models, status, meteo, constants=PlantMeteo.Constants(), extra=nothing)

    # Initialisations
    status.Tₗ = meteo.T - 0.2
    Tₗ_new = zero(meteo.T)
    status.Cₛ = meteo.Cₐ
    status.Dₗ = meteo.VPD
    γˢ = Rbₕ = Δ = zero(meteo.T)
    status.Rn = status.Rₛ
    iter = 0
    # ?NB: We use iter = 0 and not 1 to get the right number of iterations at the end
    # of the for loop, because we use iter += 1 at the end (so it increments once again)

    # Iterative resolution of the energy balance
    for i in 1:models.energy_balance.maxiter

        # Update A, Gₛ, Cᵢ from models.status:
        photosynthesis!_(models.photosynthesis, models, status, meteo, constants, extra)

        # Stomatal resistance to water vapor
        Rsᵥ = 1.0 / (gsc_to_gsw(mol_to_ms(status.Gₛ, meteo.T, meteo.P, constants.R, constants.K₀),
            constants.Gsc_to_Gsw))

        # Re-computing the net radiation according to simulated leaf temperature:
        status.Rₗₗ = net_longwave_radiation(status.Tₗ, meteo.T, models.energy_balance.ε, meteo.ε,
            status.sky_fraction, constants.K₀, constants.σ)
        #= ? NB: we use the sky fraction here (0-2) instead of the view factor (0-1) because:
            - we consider both sides of the leaf at the same time (1 -> leaf sees sky on one face)
            - we consider all objects in the scene have the same temperature as the leaf
            of interest except the atmosphere. So the leaf exchange thermal energy_balance only with
            the atmosphere. =#
        # status.Rₗₗ = (grey_body(meteo.T,1.0) - grey_body(status.Tₗ, 1.0))*status.sky_fraction

        status.Rn = status.Rₛ + status.Rₗₗ

        # Leaf boundary conductance for heat (m s-1), one sided:
        status.Gbₕ = gbₕ_free(meteo.T, status.Tₗ, status.d, constants.Dₕ₀) +
                     gbₕ_forced(meteo.Wind, status.d)
        # NB, in MAESPA we use Rni so we add the radiation conductance also (not here)

        # Leaf boundary resistance for heat (s m-1):
        Rbₕ = 1 / status.Gbₕ

        # Leaf boundary resistance for water vapor (s m-1):
        Rbᵥ = 1 / gbh_to_gbw(status.Gbₕ)

        # Leaf boundary conductance for CO₂ (mol[CO₂] m-2 s-1):
        status.Gbc = ms_to_mol(status.Gbₕ, meteo.T, meteo.P, constants.R, constants.K₀) /
                     constants.Gbc_to_Gbₕ

        # Update Cₛ using boundary layer conductance to CO₂ and assimilation:
        status.Cₛ = min(meteo.Cₐ, meteo.Cₐ - status.A / (status.Gbc * models.energy_balance.aₛᵥ))

        # Apparent value of psychrometer constant (kPa K−1)
        γˢ = PlantMeteo.γ_star(meteo.γ, models.energy_balance.aₛₕ, models.energy_balance.aₛᵥ, Rbᵥ, Rsᵥ, Rbₕ)

        status.λE = latent_heat(status.Rn, meteo.VPD, γˢ, Rbₕ, meteo.Δ, meteo.ρ,
            models.energy_balance.aₛₕ, constants.Cₚ)

        # If potential evaporation is needed, here is how to compute it:
        # γˢₑ = γ_star(meteo.γ, energy_balance.aₛₕ, 1, Rbᵥ, 1.0e-9, Rbₕ) # Rsᵥ is inf. low
        # Ev = latent_heat(status.Rn, meteo.VPD, γˢₑ, Rbₕ, meteo.Δ, meteo.ρ, energy_balance.aₛₕ, constants.Cₚ)

        Tₗ_new = meteo.T + (status.Rn - status.λE) /
                           (meteo.ρ * constants.Cₚ * (models.energy_balance.aₛₕ / Rbₕ))

        if abs(Tₗ_new - status.Tₗ) <= models.energy_balance.ΔT
            break
        end

        status.Tₗ = Tₗ_new

        # Vapour pressure difference between the surface and the saturation vapour pressure:
        status.Dₗ = PlantMeteo.e_sat(status.Tₗ) - PlantMeteo.e_sat(meteo.T) * meteo.Rh

        iter += 1
    end

    status.H = sensible_heat(status.Rn, meteo.VPD, γˢ, Rbₕ, meteo.Δ, meteo.ρ,
        models.energy_balance.aₛₕ, constants.Cₚ)

    status.iter = iter

    @debug begin
        if iter == models.energy_balance.maxiter
            "`energy_balance!_` algorithm did not converge. Please check the value."
        end
    end

    # Transpiration (mol[H₂O] m-2 s-1):
    # ET = status.λE / meteo.λ * constants.Mₕ₂ₒ
    # ET / constants.Mₕ₂ₒ to get mm s-1 <=> kg m-2 s-1 <=> l m-2 s-1

    nothing
end

"""
    latent_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ, Cₚ)
    latent_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ)

λE -the latent heat flux (W m-2)- using the Monteith and Unsworth (2013) definition corrected by
Schymanski et al. (2017), eq.22.

- `Rn` (W m-2): net radiation. Carefull: not the isothermal net radiation
- `VPD` (kPa): air vapor pressure deficit
- `γˢ` (kPa K−1): apparent value of psychrometer constant (see `PlantMeteo.γ_star`)
- `Rbₕ` (s m-1): resistance for heat transfer by convection, i.e. resistance to sensible heat
- `Δ` (KPa K-1): rate of change of saturation vapor pressure with temperature (see `PlantMeteo.e_sat_slope`)
- `ρ` (kg m-3): air density of moist air.
- `aₛₕ` (1,2): number of sides that exchange energy for heat (2 for leaves)
- `Cₚ` (J K-1 kg-1): specific heat of air for constant pressure

# References

Monteith, J. and Unsworth, M., 2013. Principles of environmental physics: plants, animals, and the atmosphere. Academic Press. See eq. 13.33.

Schymanski et al. (2017), Leaf-scale experiments reveal an important omission in the Penman–Monteith equation,
Hydrology and Earth System Sciences. DOI: https://doi.org/10.5194/hess-21-685-2017. See equ. 22.

# Examples

```julia
Tₐ = 20.0 ; P = 100.0 ;
ρ = air_density(Tₐ, P) # in kg m-3
Δ = e_sat_slope(Tₐ)

latent_heat(300.0, 2.0, 0.1461683, 50.0, Δ, ρ, 2.0)
```
"""
function latent_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ, Cₚ)
    (Δ * Rn + ρ * Cₚ * VPD * (aₛₕ / Rbₕ)) / (Δ + γˢ)
end

function latent_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ)
    latent_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ, PlantMeteo.Constants().Cₚ)
end


"""
    sensible_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ, Cₚ)
    sensible_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ)

H -the sensible heat flux (W m-2)- using the Monteith and Unsworth (2013) definition corrected by
Schymanski et al. (2017), eq.22.

- `Rn` (W m-2): net radiation. Carefull: not the isothermal net radiation
- `VPD` (kPa): air vapor pressure deficit
- `γˢ` (kPa K−1): apparent value of psychrometer constant (see `PlantMeteo.γ_star`)
- `Rbₕ` (s m-1): resistance for heat transfer by convection, i.e. resistance to sensible heat
- `Δ` (KPa K-1): rate of change of saturation vapor pressure with temperature (see `PlantMeteo.e_sat_slope`)
- `ρ` (kg m-3): air density of moist air.
- `aₛₕ` (1,2): number of sides that exchange energy for heat (2 for leaves)
- `Cₚ` (J K-1 kg-1): specific heat of air for constant pressure

# References

Monteith, J. and Unsworth, M., 2013. Principles of environmental physics: plants, animals, and the atmosphere. Academic Press. See eq. 13.33.

Schymanski et al. (2017), Leaf-scale experiments reveal an important omission in the Penman–Monteith equation,
Hydrology and Earth System Sciences. DOI: https://doi.org/10.5194/hess-21-685-2017. See equ. 22.

# Examples

```julia
Tₐ = 20.0 ; P = 100.0 ;
ρ = air_density(Tₐ, P) # in kg m-3
Δ = e_sat_slope(Tₐ)

sensible_heat(300.0, 2.0, 0.1461683, 50.0, Δ, ρ, 2.0)
```
"""
function sensible_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ, Cₚ)
    (γˢ * Rn - ρ * Cₚ * VPD * (aₛₕ / Rbₕ)) / (Δ + γˢ)
end

function sensible_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ)
    sensible_heat(Rn, VPD, γˢ, Rbₕ, Δ, ρ, aₛₕ, PlantMeteo.Constants().Cₚ)
end
