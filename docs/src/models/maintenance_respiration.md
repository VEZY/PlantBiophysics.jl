# Maintenance respiration at organ temperature

`Q10MaintenanceRespiration` applies a biomass-based Q10 law to the current
temperature of an organ. It does not assume that organ temperature equals
air temperature. Configure one model per tissue or homogeneous organ group;
organ coefficients and biomass estimates belong to your application.

```@example organ_maintenance
using PlantBiophysics, PlantSimEngine, PlantMeteo, Dates

# Illustrative values only; these are not package or species defaults.
respiration = Q10MaintenanceRespiration(
    Q10=2.0, Mr=0.002, T_ref=25.0, P_alive=0.5,
)
scene = CompositeModel(respiration;
    status=Status(structural_mass_gDM=1000.0, organ_temperature_C=25.0),
    environment=Atmosphere(T=20.0, Rh=0.6, Wind=1.0, duration=Hour(1)),
)
run!(scene)
s = only(model_objects(scene)).status
(daily_rate=s.Rm_gCH2O_per_day_at_T, co2_rate=s.Rm_CO2_umol_s)
```

The reference rate is `1000 × 0.5 × 0.002 = 1 g CH₂O-equivalent/day`.
One hour at that rate releases `1/24 g CH₂O-equivalent`, not one gram.
The CO₂ output is `1/30.026 × 10⁶/86400 ≈ 0.3855 µmol CO₂/s`.
CH₂O-equivalent, elemental carbon, dry biomass and CO₂ mass are different
quantities; converting between them requires the corresponding chemical basis.

| Quantity | Meaning |
|:--|:--|
| `structural_mass_gDM` | Existing structural dry mass of the represented organ, in g |
| `P_alive` | Fraction of that mass to which the coefficient applies |
| `Mr` | g CH₂O-equivalent per g living dry matter per day at `T_ref` |
| `organ_temperature_C` | Current organ temperature, °C |
| `Rm_gCH2O_per_day_at_T` | Positive release rate, g CH₂O-equivalent/day per organ |
| `Rm_CO2_umol_s` | The same release rate in µmol CO₂/s per organ |

The physiological parameters are required explicitly. If a coefficient already
describes an entire organ including inactive tissue, set `P_alive=1`; otherwise
the living fraction would be counted twice. The module provides no palm-specific
tissue fractions, densities, SLA, or allocation coefficients.
At a given temperature, flux constrains the product of biomass, living fraction
and `Mr`; those factors cannot all be inferred independently from the same
respiration observations. Fix or measure the mass and living fraction before
interpreting a fitted coefficient as a tissue property.

Outputs remain rates when passed to a coarser clock: the declared policy takes
a duration-weighted mean. To obtain an interval amount, explicitly integrate the
CO₂ rate with elapsed seconds, or the daily-equivalent rate with elapsed days.
For a contracted carbon-budget consumer, use an adapter that declares the rate
input and the resulting amount output; a rate and an amount have different
contracts. Do not multiply an already integrated output by duration again.

## Combine respiration with leaf photosynthesis

The model never changes `A`. FvCB net assimilation already subtracts the
mitochondrial term `Rd`. To add respiration from stems, petioles or other
nonassimilating organs, first sum leaf `A × leaf area`, then subtract the
represented nonleaf `Rm_CO2_umol_s` once. Both terms are extensive µmol CO₂/s
on the same plant/chamber boundary. Include roots only if they belong inside
that boundary.

Replacing FvCB leaf respiration with this biomass law requires a deliberate
change to the coupled biochemical model. Simply subtracting a second leaf
maintenance estimate from net `A` double-counts leaf respiration. Restoring
old `Rd` after a simulation also does not recompute its effects on internal
CO₂, stomata and leaf temperature.

This local Q10 response has no acclimation, growth respiration, substrate
limitation or tissue-death dynamics. Nighttime and daytime-darkening fluxes
can include growth and transport costs, so fitting all dark efflux does not
by itself identify maintenance respiration.

Henson (2004), [*Estimating maintenance respiration of oil palm*](https://opb.mpob.gov.my/estimating-maintenance-respiration-of-oil-palm/),
describes the biomass, tissue and temperature bookkeeping that motivated the
prototype. Its tissue coefficients are not imported as generic defaults.
