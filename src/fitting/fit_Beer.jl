"""
    Evaluation.fit(::Type{Beer}, df; J_to_umol=PlantMeteo.Constants().J_to_umol)

Estimate `k`, the coefficient of the Beer-Lambert law of light extinction, by
inverting the absorbed fraction in each observation:

`f_abs = aPPFD / (Ri_PAR_f * J_to_umol)` and
`k = -log1p(-f_abs) / LAI`.

# Arguments

- `df`: a DataFrame with columns `Ri_PAR_f` (incoming PAR in W m[ground]⁻²),
  `aPPFD` (absorbed PAR in μmol[PAR] m[ground]⁻² s⁻¹), and `LAI`
  (m[leaf]² m[ground]⁻²), where each row is an observation. `Ri_PAR_f` and
  `aPPFD` therefore use the same ground-area basis; `aPPFD` is not expressed
  per unit leaf area here. Column names must match exactly.

`LAI`, each `Ri_PAR_f`, and `J_to_umol` must independently be finite and
strictly positive. Their converted incident PAR must remain finite and positive,
and the implied absorbed fraction must satisfy `0 ≤ f_abs < 1`. An empty table
throws `ArgumentError`; invalid observations throw a `DomainError` identifying
the row and quantity.

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

# Fit the parameter value:
fitted = Evaluation.fit(Beer, df)

# Re-simulating the first observation using the newly fitted parameter:
meteo = Atmosphere(
    T = df.T[1],
    Rh = df.Rh[1],
    Wind = df.Wind[1],
    Ri_PAR_f = df.Ri_PAR_f[1],
)
scene = CompositeModel(
    Object(:plant; scale = :Plant, status = Status(LAI = df.LAI[1]));
    applications = (
        ModelSpec(
            Beer(fitted.k);
            name = :canopy_light,
            on = One(scale = :Plant),
        ),
    ),
    environment = meteo,
)
run!(scene)
model_object(scene, :plant).status.aPPFD
```
"""
function PlantSimEngine.Evaluation.fit(::Type{Beer}, df; J_to_umol=PlantMeteo.Constants().J_to_umol)
    (J_to_umol isa Real && isfinite(J_to_umol) && J_to_umol > 0) || throw(
        DomainError(
            J_to_umol,
            "Beer fit requires a finite J_to_umol > 0; got $(repr(J_to_umol))",
        ),
    )

    k_observations = map(eachindex(df.LAI, df.Ri_PAR_f, df.aPPFD)) do row
        lai = df.LAI[row]
        (lai isa Real && isfinite(lai) && lai > 0) || throw(
            DomainError(
                lai,
                "Beer fit requires finite LAI > 0 at row $(row); got $(repr(lai))",
            ),
        )

        incident_par = df.Ri_PAR_f[row]
        (incident_par isa Real && isfinite(incident_par) && incident_par > 0) || throw(
            DomainError(
                incident_par,
                "Beer fit requires finite Ri_PAR_f > 0 at row $(row); " *
                "got $(repr(incident_par))",
            ),
        )

        incident_ppfd = incident_par * J_to_umol
        (incident_ppfd isa Real && isfinite(incident_ppfd) && incident_ppfd > 0) || throw(
            DomainError(
                incident_ppfd,
                "Beer fit requires finite incident PAR > 0 at row $(row) to define " *
                "an absorbed fraction; got $(repr(incident_ppfd))",
            ),
        )

        f_abs = df.aPPFD[row] / incident_ppfd
        (f_abs isa Real && isfinite(f_abs) && 0 <= f_abs < 1) || throw(
            DomainError(
                f_abs,
                "Beer fit requires an absorbed fraction in [0, 1) at row $(row); " *
                "got $(repr(f_abs))",
            ),
        )

        k_observation = -log1p(-f_abs) / lai
        isfinite(k_observation) || throw(
            DomainError(
                k_observation,
                "Beer fit produced a non-finite extinction coefficient at row $(row)",
            ),
        )
        k_observation
    end
    isempty(k_observations) && throw(
        ArgumentError("Beer fit requires at least one observation"),
    )
    k = Statistics.mean(k_observations)
    isfinite(k) || throw(DomainError(k, "Beer fit produced a non-finite mean coefficient"))
    return (k=k,)
end
