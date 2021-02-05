"""
    e(Tₐ, VPD)
Vapor pressure (kPa) at given temperature and VPD.
"""
function e(Tₐ, VPD)
    get_eₛ(Tₐ) - VPD
end


"""
    e_sat(T)

Saturated water vapour pressure (es, in kPa) at given temperature `T` (°C).
See Jones (1992) p. 110 for the equation.
"""
function e_sat(T)
  0.61375 * exp((17.502 * T) / (T + 240.97))
end

"""
    e_sat_slope(T)

Slope of the vapor pressure saturation curve at a given temperature `T` (°C).
"""
function e_sat_slope(T)
  (e_sat(T + 0.1) - e_sat(T)) / 0.1
end
