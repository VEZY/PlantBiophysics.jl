function photosynthesis(leaf::Leaf)
    A = assimiliation(leaf.assimilation, leaf.conductance)
    Gs = conductance(leaf.conductance,leaf.assimilation)
end


"""
    assimiliation(A::Fvcb,Gs::GsModel)

Photosynthesis using the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis
 (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981).
Computation is made following Farquhar & Wong (1984), Leuning et al. (1995), and the
MAESPA model (Duursma et al., 2012).
The resolution is analytical as first presented in Baldocchi (1994).

# References

Baldocchi, Dennis. 1994. « An analytical solution for coupled leaf photosynthesis and
stomatal conductance models ». Tree Physiology 14 (7-8‑9): 1069‑79.
https://doi.org/10.1093/treephys/14.7-8-9.1069.

Duursma, R. A., et B. E. Medlyn. 2012. « MAESPA: a model to study interactions between water
limitation, environmental drivers and vegetation function at tree and stand levels, with an
example application to [CO2] × drought interactions ». Geoscientific Model Development 5
(4): 919‑40. https://doi.org/10.5194/gmd-5-919-2012.

Farquhar, G. D., S. von von Caemmerer, et J. A. Berry. 1980. « A biochemical model of
photosynthetic CO2 assimilation in leaves of C3 species ». Planta 149 (1): 78‑90.

Leuning, R., F. M. Kelliher, DGG de Pury, et E.-D. SCHULZE. 1995. « Leaf nitrogen,
photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant,
Cell & Environment 18 (10): 1183‑1200.

"""
function assimiliation(A::Fvcb,Gs::GsModel,Constants)
    g₀ = Gs.g0 # residual conductance for CO2 in μmol[CO2] m-2 s-1
    Γˢ = Γ_star(T,A.Tᵣ,Constants) # Gamma star (CO2 compensation point) in μmol mol-1
    Km = Km(T,A.Tᵣ,A.O₂,Constants) # effective Michaelis–Menten coefficient for CO2

    # continue here
    JMAX = JMAXTFN(A.JMaxRef,T,EAVJ,EDVJ,DELSJ,TVJUP,TVJDN)
    VCMAX = VCMAXTFN(A.VcMaxRef,T,EAVC,EDVC,DELSC,TVJUP,TVJDN)
    RD = RESP(RD0,RD0ACC,T,TMOVE,Q10F,K10F,RTEMP,DAYRESP,TBELOW)

end

function assimiliation(A::Fvcb,Gs::GsModel)
    assimiliation(A,Gs,Constants())
end
