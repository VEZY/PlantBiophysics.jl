
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
function energy_balance(Tₐ,Wind,Rh,Rn,rsw,P,Wₗ,maxiter=10,adjustrn= TRUE,
                        hypostomatous= TRUE,Dheat= 2.15e-05, skyFraction= 2,
                        constants)


  esat= get_eₛ(Tₐ)
  vpd= esat - Rh * esat
  Tₗ = Tₐ
  tLeafCalc = 0.0
  delta_t= 0.0
  GBVGBH = 1.075
  rn_2= Rn

  ρ = air_density(Tₐ, P, constants.Rd, constants.K₀)

  γ = psychrometric_constant(Tₐ, P, constants.Cₚ, constants.ε)




  # Monteith and unsworth (2013), eq. 13.32, corrigendum from Schymanski et al. (2017):
  a_sh= 2 # both sides exchange H
  if hypostomatous
    a_s= 1
  else
    a_s= 2
  end


  for i in 1:maxiter

    if adjustrn
      R_ll= (black_body(Temp = Tₐ,emissivity = 1.0)-black_body(Temp = Tₗ,emissivity = 1.0))*skyFraction
      rn_2= Rn + R_ll
    end

    Gbh=
      Gb_hFree(Tₐ= Tₐ, Tₗ= Tₗ, Wₗ= Wₗ, Dheat= Dheat)+
      Gb_hForced(Wind = Wind, Wₗ = Wₗ)
    # NB, in MAESPA we use Rni so we add the radiation conductance also (not here)

    rbh= 1/(Gbh)
    rbv = 1/(Gbh*GBVGBH)
    # gamma_star= n_hypo * gamma * (rbv + rsw)/rbh
    gamma_star= gamma * a_sh/a_s * (rbv + rsw)/rbh
    # rv + rsw= Boundary + stomatal conductance to water vapour

    ## Attention delta, ea et esTa expressed in KPa
    delta = slope(Tₐ = Tₐ)

    LE= latent_heat_MAESPA(Rn = rn_2, Tₐ = Tₐ, vpd = vpd, gamma_star = gamma_star, rbh = rbh,
                           delta = delta, ρ= ρ, Cₚ= constants.Cₚ,a_sh)

    tLeafCalc= Tₐ + (rn_2 - LE) / (ρ*constants.Cₚ * (a_sh/rbh))

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


  H= sensible_heat_MAESPA(Rn = rn_2, Tₐ = Tₐ, vpd = vpd, gamma_star = gamma_star, rbh = rbh,
                      delta = delta, ρ= ρ, Cₚ= constants.Cₚ, a_sh= a_sh)



  return (Rn= rn_2, Tl= Tₗ, Tₐ= Tₐ, H= H, LE= LE, rbh= rbh, rbv= rbv, iter= i)
end

"""
    get_eₛ(T)

Saturated water vapour pressure (es, in kPa) at given temperature `T` in Celsius degree.
See Jones (1992) p. 110 for the equation.
"""
function get_eₛ(T)
  0.61375 * exp(17.502 * T / (T + 240.97))
end

function slope(Tₐ,Tl)
  (get_eₛ(Tₐ + 0.1) - get_eₛ(Tₐ)) / 0.1
end


function latent_heat_MAESPA(Rn, Tₐ, vpd, gamma_star, rbh, delta, ρ, Cₚ= 1004.834,a_sh=2)
  (delta * Rn + ρ * Cₚ * vpd * (a_sh/rbh))/(delta + gamma_star)
end

function sensible_heat_MAESPA(Rn, Tₐ, vpd, gamma_star, rbh, delta, ρ, Cₚ,a_sh=2)
  (gamma_star*Rn-ρ*Cₚ*vpd*(a_sh/rbh))/(delta+gamma_star)
end

"""

Leaf boundary layer conductance for heat under free convection (m s-1).

# Arguments

- `Tₐ` (°C): air temperature
- `Tₗ` (°C): leaf temperature
- `P` (kPa): air pressure
- `Wₗ` (m): leaf width (`d` in eq. 10.9 from Monteith and Unsworth, 2013).
- `R = 8.314`: universal gas constant (``J\\ mol^{-1}\\ K^{-1}``).
- `Dₕ₀ = 21.5e-6`: molecular diffusivity for heat at base temperature.

# Notes

`R` and `Dₕ₀` can be found using [`Constants`](@Ref).

# References

Leuning, R., F. M. Kelliher, DGG de Pury, et E.-D. SCHULZE. 1995. « Leaf nitrogen,
photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant,
Cell & Environment 18 (10): 1183‑1200.

Monteith, John, et Mike Unsworth. 2013. Principles of environmental physics: plants,
animals, and the atmosphere. Academic Press. Paragraph 10.1.3, eq. 10.9.
"""
function get_Gbₕ_free(Tₐ,Tₗ,P,Wₗ,R,Dₕ₀)
    # CMOLAR = P / (R * TK(Tₐ)) # Keep it ? Used to transorm in mol m-2 s-1 from m s-1

    if (Tₗ-Tₐ) > 0.0
        Gr = 1.58e8 * Wₗ^3.0 * abs(Tₗ-Tₐ) # Grashof number (Monteith and Unsworth, 2013)
        # !Note: Leuning et al. (1995) use 1.6 (eq. E4).
        # Leuning et al. (1995) eq. E3:
        Gbₕ_free = 0.5 * get_Dₕ(Dₕ₀, Tₐ) * (Gr^0.25) / Wₗ * CMOLAR
    else
        Gbₕ_free = 0.0
    end

    return Gbₕ_free
end



"""
    get_Dₕ(Dₕ₀,T)

Dₕ -molecular diffusivity for heat at base temperature- from Dₕ₀ (corrected by temperature).
See Monteith and Unsworth (2013, eq. 3.10).

# References

Monteith, John, et Mike Unsworth. 2013. Principles of environmental physics: plants,
animals, and the atmosphere. Academic Press. Paragraph 10.1.3., eq. 10.9.
"""
function get_Dₕ(Dₕ₀,T)
    Dₕ₀ + Dₕ₀ * (1 + 0.007*T)
end
