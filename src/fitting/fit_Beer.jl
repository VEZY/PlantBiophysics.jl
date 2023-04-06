"""
    fit(::Type{Beer}, df; J_to_umol=PlantMeteo.Constants().J_to_umol)

Optimize `k`, the coefficient of the Beer-Lambert law of light extinction.

# Arguments

- df: a DataFrame with columns Ri_PAR_f (Incoming light flux in the PAR, W m⁻²), 
aPPFD (μmol m⁻² s⁻¹) and LAI (m² m⁻²), where each row is an observation. The column
names should match exactly.

# Examples

```julia
using PlantSimEngine, PlantBiophysics, DataFrames, PlantMeteo

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
k = fit(Beer, df)

# Re-simulating aPPFD using the newly fitted parameters:
w = Weather(df)
leaf = ModelList(
        Beer(k.k),
        status = (LAI = df.LAI,)
    )
run!(leaf, w)

leaf
```
"""
function PlantSimEngine.fit(::Type{Beer}, df; J_to_umol=PlantMeteo.Constants().J_to_umol)
    k = Statistics.mean(log.(df.Ri_PAR_f ./ (df.aPPFD ./ J_to_umol)) ./ df.LAI)
    return (k=k,)
end