"""
    Evaluation.fit(::Type{Beer}, df; J_to_umol=PlantMeteo.Constants().J_to_umol)

Optimize `k`, the coefficient of the Beer-Lambert law of light extinction.

# Arguments

- df: a DataFrame with columns Ri_PAR_f (Incoming light flux in the PAR, W m⁻²), 
aPPFD (μmol m⁻² s⁻¹) and LAI (m² m⁻²), where each row is an observation. The column
names should match exactly.

# Examples

```julia
using PlantSimEngine, PlantSimEngine.Evaluation, PlantBiophysics, DataFrames, PlantMeteo

# Defining dummy data:
df = DataFrame(
    Ri_PAR_f = [200.0, 250.0, 300.0], 
    aPPFD = [548.4, 685.5, 822.6], 
    LAI = [1.0, 1.0, 1.0],
    T = [20.0, 20.0, 20.0],
    Rh = [0.5, 0.5, 0.5],
    Wind = [10.0, 10.0, 10.0],
)

# Fit the parameters values:
k = Evaluation.fit(Beer, df)

# Re-simulating the first observation using the newly fitted parameter:
meteo = Atmosphere(
    T = df.T[1],
    Rh = df.Rh[1],
    Wind = df.Wind[1],
    Ri_PAR_f = df.Ri_PAR_f[1],
)
scene = leaf_scene(Beer(k.k); status = Status(LAI = df.LAI[1]), environment = meteo)
run!(scene)
only(model_objects(scene; scale = :Leaf)).status.aPPFD
```
"""
function PlantSimEngine.Evaluation.fit(::Type{Beer}, df; J_to_umol=PlantMeteo.Constants().J_to_umol)
    k = Statistics.mean(log.(df.Ri_PAR_f ./ (df.aPPFD ./ J_to_umol)) ./ df.LAI)
    return (k=k,)
end
