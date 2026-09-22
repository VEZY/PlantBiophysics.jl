# Model evaluation

This page compares simulated assimilation, transpiration, stomatal
conductance, leaf temperature, and energy fluxes with measurements used in
the package paper. The figures show the PlantBiophysics results.

## How to read the figures

In an observed-versus-simulated plot, points close to the 1:1 line indicate
agreement. Each panel reports two measures:

- **NRMSE** is the root mean squared error divided by the observed range.
  Smaller values indicate less error.
- **EF** is modelling efficiency. A value of 1 indicates perfect agreement;
  0 is equivalent to always predicting the mean observation, and negative
  values indicate a poorer prediction than that mean.

The descriptions below identify which quantities are simulated and which
are supplied from measurements. This matters when interpreting a model's
performance, especially when stomatal conductance is prescribed.

## Global evaluation

![Observed and simulated A, E, Gs, and Tl for PlantBiophysics](assets/evaluation/medlyn_global.svg)

The coupled FvCB--Medlyn--Monteith simulation is evaluated against the
Tumbarumba gas-exchange measurements from
[Medlyn, Pepper, and Keith (2015)](https://doi.org/10.6084/m9.figshare.1538079.v1).
The paper's `Ca > 150 ppm` quality filter leaves 536 observations. Each
observation is evaluated once; this avoids the duplicated timestamp matches in
the historical paper workflow. The grey line is the 1:1 relationship.

## Daily evaluation

![Daily observations, PlantBiophysics simulations, and propagated uncertainty](assets/evaluation/medlyn_daily.svg)

This six-observation sequence is for tree 3 on 14 November 2001 in the same
Tumbarumba dataset. The line is the mean of 2,000 uncertainty-propagation
particles, and the shaded ribbon spans their 2.5th to 97.5th percentiles.

Measured stomatal conductance is forced in this scenario because these spot
measurements do not provide the response curve needed to fit a stomatal model.
The figure therefore evaluates the photosynthesis and energy-balance response
conditional on measured conductance; it is not an independent validation of
stomatal conductance.

## [Schymanski et al. (2017)](@id schymanski-evaluation)

![Observed and simulated leaf energy fluxes across wind speeds](assets/evaluation/schymanski_energy_fluxes.svg)

Points are observations and lines are PlantBiophysics simulations for the
wind-speed experiment underlying figure 6a of
[Schymanski and Or (2017)](https://doi.org/10.5194/hess-21-685-2017).
The plotted fluxes are latent heat (`λE`), sensible heat (`H`), net radiation
(`Rn`), and the observed energy sum (`H + λE`).

Measured stomatal conductance, radiative forcing, and chamber conditions are
prescribed. This is consequently a targeted evaluation of the energy-balance
implementation rather than a fully independent evaluation of the coupled
leaf model. The source data come from the
[`Schymanski_leaf-scale_2016`](https://github.com/schymans/Schymanski_leaf-scale_2016)
repository.

To reproduce only this panel, run the
[standalone Schymanski wrapper](models/schymanski.jl) from the repository root:

```bash
julia --project=docs docs/src/models/schymanski.jl
```

The wrapper calls the same scenario as the numerical regression tests and the
same plotting code as the complete documentation build; it does not maintain a
second copy of the scientific computation.

## Reproducing the figures

The SVG files are regenerated at the start of every Documenter build.
Generation uses only the committed offline test fixtures. To regenerate the
figures without building the rest of the documentation, instantiate the
`docs` environment and run:

```bash
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/figures/generate_evaluation_figures.jl
```

The figures and numerical regression tests share the same scenarios, inputs,
parameters, filters, and unit conversions. The tests compare NRMSE, RMSE,
bias, normalized bias, and EF with the paper repository's reference results.
Their tolerances allow small numerical differences while detecting a
meaningful loss of model performance.

The Medlyn fixtures are distributed under CC BY 4.0. Their file identifiers,
checksums, extraction history, and the provenance note for the Schymanski data
are recorded in `test/inputs/evaluation/README.md`.
