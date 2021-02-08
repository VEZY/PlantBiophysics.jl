"""
    ms_to_mol(T,P,R,K₀)
    ms_to_mol(T,P)

Conversion of a conductance from ``m\\ s^{-1}`` to ``mol\\ m^{-2}\\ s^{-1}``.
"""
function ms_to_mol(T,P,R,K₀)
    P / (R * (T - K₀))
end

function ms_to_mol(T,P)
    constants = Constants()
    ms_to_mol(T,P,constants.R,constants.K₀)
end
