# Changelog

## Unreleased

### Fixed

- `Fvcb` now solves signed net assimilation, stomatal conductance, and CO₂
  diffusion consistently at zero, low, and high light. Zero-light net
  assimilation remains `A = -Rd`, preserving nighttime respiration. Negative
  `A` can produce `Cᵢ > Cₛ`; low-light photosynthesis is retained before
  subtracting respiration. Medlyn and Tuzet
  conductance floors are included as analytical solution branches. Prescribed
  `ConstantGs` conductance no longer depends on division by assimilation.

### Added

- `gs_coupling` exposes the affine conductance relation used by the analytical
  `Fvcb` solver. Custom conductance models can declare their intercept, slope,
  and floor explicitly; a nonlinear dependence on assimilation requires a
  different coupled solution.

## 0.18.0

This release adopts PlantSimEngine 0.15's `CompositeModel` API and makes radiation
units and reference areas explicit when coupling light interception and leaf
physiology. It requires PlantMeteo 0.9 and Julia 1.10 or later.

### Breaking changes

- Simulation examples and model kernels now use the PlantSimEngine 0.15 API.
  Replace `ModelMapping` with `CompositeModel(model...; status=Status(...),
  environment=...)` for a single object. Use `Object`, `ModelSpec`, and selectors
  for simulations with several objects or explicit coupling. Run the configured
  model with `run!(scene)` and export results with
  `collect_outputs(simulation; sink=DataFrame)`.
- Custom model kernels now receive `(model, status, environment, constants,
  context)` instead of a bundle of models. Required state inputs are declared
  with `PlantSimEngine.Required`, and meteorological inputs with
  `environment_inputs_`.
- Coupled Monteith, FvCB, FvCBIter, and ConstantAGs models must run in a compiled
  `CompositeModel`. They execute their declared dependencies through
  `run_call!`; targets are selected within the same object using `Self()`,
  without requiring the object to be named or scaled `Leaf`.
- Parameter fitting is now available through `PlantSimEngine.Evaluation.fit`.
  Import `PlantSimEngine.Evaluation` and use `Evaluation.fit(ModelType, data;
  options...)`. Evaluation statistics such as `RMSE`, `EF`, and `dr` also use
  this namespace.
- `Beer` and `BeerShortwave` now keep their canopy radiation outputs as current
  per-second rates. Temporal totals are no longer selected implicitly through
  `output_policy`; request `Integrate(...)` explicitly in an `OutputRequest`
  when exporting totals. Model-to-model bindings remain rate-valued; a model
  that consumes a total needs a separate, explicitly contracted adapter.
- Radiation normalization is now checked during model compilation. Beer
  outputs are per ground area, while FvCB and Monteith inputs use the
  `:surface_area` basis. Use `GroundToMeanLeafPPFD` or
  `GroundToMeanLeafShortwave` at the canopy boundary. Geometry-resolved
  ArchimedLight outputs use the same represented mesh surface as physiology
  and couple directly, without a separate leaf-area correction. The component
  diagnostics `Ra_PAR_f` and `Ra_NIR_f` remain uncontracted so neither can be
  renamed into the canonical PAR+NIR shortwave input.
- Removed the historical ARCHIMED YAML `read_model` parser and its parser-only
  helper API. Construct physiology models explicitly; use
  `ArchimedLight.read_models` for ARCHIMED optical model files.
- Removed the unimplemented `Translucent` MTG-array copier, the no-op
  `LightIgnore` model, and PlantBiophysics' conflicting `OpticalProperties`
  types. Couple a light producer with `outputs_to`, or omit light interception.

### Added

- `ConstantAbsorption` computes absorbed PAR, NIR, total shortwave radiation,
  and `aPPFD` from prescribed PAR and NIR absorption fractions. Incident and
  absorbed radiation use the same represented surface area. This model is
  useful for prescribed light conditions, such as a measurement chamber; it
  does not simulate canopy shading.
- `GroundToMeanLeafPPFD` and `GroundToMeanLeafShortwave` convert canopy radiation
  per ground area to mean radiation per leaf area using LAI.
- Regression tests based on the published global evaluation, daily evaluation,
  and Schymanski leaf energy-balance cases.

### Fixed

- Beer extinction fitting now inverts the absorbed fraction with
  `k = -log1p(-f_abs) / LAI`, where
  `f_abs = aPPFD / (Ri_PAR_f * J_to_umol)`. It rejects empty data and invalid
  observations, including non-positive incident radiation or LAI and absorbed
  fractions outside `[0, 1)`.
- Tuzet now declares assimilation `A` as a required input, allowing
  PlantSimEngine to validate it and infer its dependency on an assimilation
  producer.

### Changed

- Package and test environments use registered PlantSimEngine 0.15 dependencies.
  The core test suite no longer installs or tests ArchimedLight; geometry-based
  light coupling is documented as an optional integration.
- Added compatibility with CSV 1.0 and OrderedCollections 2.0.
- `BeerShortwave(k)` retains its historical `k_NIR = 0.48` default.

### Documentation

- Rebuilt the documentation with Bonito, a new landing page, static figures,
  and examples for fitting parameters and simulating daily oil-palm assimilation.
- Updated tutorials to use `CompositeModel` directly and explain required
  inputs, output collection, uncertainty propagation, simulations with several
  objects, multiple simulation rates, and coupling light with physiology.
- Added static-export checks and documentation builds for pull requests.

### Deprecations

- Use `Fvcb_net_assimilation`; the misspelled
  `Fvcb_net_assimiliation` compatibility wrapper will be removed in v0.20.
