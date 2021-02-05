
"""

Leaf energy balance according to Monteith and Unsworth (2013), and corrigendum from
Schymanski et al. (2017). The computation is close to the one from the MAESPA model (Duursma
et al., 2012, Vezy et al., 2018) here. The leaf temperature is computed iteratively to close
the energy balance using the mass flux (~ Rn - LE).

The other approach (close to Archimed model) closes the energy balance using energy flux.

# Arguments

- `Tₐ` (°C): air temperature
- `Wind` (m s-1): wind speed
- `Rh` (0-1): air relative humidity
- `Rn` (W m-2): net radiation
- `Rsw` (s m-1): stomatal resistance to water vapor
- `P` (kPa): air pressure
- `Wₗ` (m): leaf width
- `Dheat` (m s-1): molecular diffusivity for heat
- `maxiter::Int`: maximum number of iterations
- `adjustrn::Bool`: adjust the Rn value for longwave emission after re-computing the leaf temperature?
- `hypostomatous::Bool`: is the leaf hypostomatous?
- `skyFraction` (0-2): fraction of sky viewed by the leaf.


# Note

The skyFraction is equal to 2 if all the leaf is viewing is sky (e.g. in a controlled chamber), 1
if the leaf is *e.g.* up on the canopy where the upper side of the leaf sees the sky, and the
side below sees soil + other leaves that are all considered at the same temperature than the leaf,
or less than 1 if it is partly shaded.

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
function energy_balance(Tₐ,Wind,Rh,Rn,rsw,P,Wₗ,maxiter=10,
                        hypostomatous= true, Dheat= 2.15e-05, skyFraction= 2,
                        constants,emissivity)
    eₐ = e(Tₐ, VPD)
    eₛ = e_sat(Tₐ)
    vpd = eₛ - Rh * eₛ
    eₐ = eₛ - vpd # we already have eₛ so we don't use `e()` for the computation here
    Tₗ = Tₐ
    tLeafCalc = 0.0
    delta_t= 0.0
    GBVGBH = 1.075

    ρ = air_density(Tₐ, P, constants.Rd, constants.K₀) # in kg m-3
    γ = psychrometric_constant(Tₐ, P, constants.Cₚ, constants.ε) # in kPa K−1

    # Monteith and unsworth (2013), eq. 13.32, corrigendum from Schymanski et al. (2017):
    a_sh = 2 # both sides exchange H
    if hypostomatous
        a_s = 1
    else
        a_s = 2
    end

    for i in 1:maxiter

        # Re-computing the net radiation according to simulated leaf temperature:
        εₐ = atmosphere_emissivity(Tₐ,eₐ,constants.K₀)
        Rₗₗ = net_longwave_radiation(Tₗ,Tₐ,emissivity,εₐ,skyFraction,constants.K₀,constants.σ)
        #= ? NB: we use the sky fraction here (0-2) instead of the view factor (0-1) because:
            - we consider both sides of the leaf at the same time (1 -> leaf sees sky on one face)
            - we consider all objects in the scene have the same temperature as the leaf
            of interest except the atmosphere. So the leaf exchange thermal energy only with
            the atmosphere.
        =#
        Rn += Rₗₗ

        # Leaf boundary conductance for heat (m s-1):
        Gbh = gbₕ_free(Tₐ, Tₗ, Wₗ, Dheat) + gbₕ_forced(Wind, Wₗ)
        # NB, in MAESPA we use Rni so we add the radiation conductance also (not here)

        rbh= 1/(Gbh)
        rbv = 1/(Gbh*GBVGBH)
        # gamma_star= n_hypo * gamma * (rbv + rsw)/rbh
        gamma_star= gamma * a_sh/a_s * (rbv + rsw)/rbh
        # rv + rsw= Boundary + stomatal conductance to water vapour

        ## Attention delta, ea et esTa expressed in KPa
        delta = e_sat_slope(Tₐ = Tₐ)

        LE= latent_heat_MAESPA(Rn = Rn, Tₐ = Tₐ, vpd = vpd, gamma_star = gamma_star, rbh = rbh,
                                delta = delta, ρ= ρ, Cₚ= constants.Cₚ,a_sh)

        tLeafCalc= Tₐ + (Rn - LE) / (ρ*constants.Cₚ * (a_sh/rbh))

        delta_t = tLeafCalc-Tₗ
        Tₗ = tLeafCalc


        # cat('Iteration',i,"\n")
        # cat('VPD',vpd, 'KPa',"\n")
        # cat('LE',LE, '(W m-2)',"\n")
        # cat('H',H, '(W m-2)',"\n")
        # cat('RBH ',rbh, '(s m-1)',"\n")
        # cat('RBV',rbv, '(s m-1)',"\n")
        # cat('------------------',"\n")

        if abs(delta_t)<=0.01 break end
    end


    H= sensible_heat_MAESPA(Rn = Rn, Tₐ = Tₐ, vpd = vpd, gamma_star = gamma_star, rbh = rbh,
                        delta = delta, ρ= ρ, Cₚ= constants.Cₚ, a_sh= a_sh)



    return (Rn= Rn, Tl= Tₗ, Tₐ= Tₐ, H= H, LE= LE, rbh= rbh, rbv= rbv, iter= i)
end


function latent_heat_MAESPA(Rn, Tₐ, vpd, gamma_star, rbh, delta, ρ, Cₚ= 1004.834,a_sh=2)
  (delta * Rn + ρ * Cₚ * vpd * (a_sh/rbh))/(delta + gamma_star)
end

function sensible_heat_MAESPA(Rn, Tₐ, vpd, gamma_star, rbh, delta, ρ, Cₚ,a_sh=2)
  (gamma_star*Rn-ρ*Cₚ*vpd*(a_sh/rbh))/(delta+gamma_star)
end
