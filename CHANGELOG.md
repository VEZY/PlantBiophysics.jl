# Changelog

## Unreleased

### Breaking changes

- Beer and BeerShortwave now keep their canopy radiation outputs as current
  per-second rates. Temporal totals are no longer selected implicitly through
  `output_policy`; request `Integrate(...)` explicitly in an `OutputRequest`
  when exporting totals. Model-to-model bindings remain rate-valued; a model
  that consumes a total needs a separate, explicitly contracted adapter.
- Radiation normalization is now checked during model compilation. Beer
  outputs are per ground area, while FvCB and Monteith inputs are per leaf
  area. Use `GroundToMeanLeafPPFD` or `GroundToMeanLeafShortwave` at that
  boundary. For geometry-resolved ArchimedLight outputs, use
  `RadiativeMeshToLeafPPFD` or `RadiativeMeshToLeafShortwave` with explicit
  `radiative_mesh_area` and `botanical_leaf_area`. The component diagnostics
  `Ra_PAR_f` and `Ra_NIR_f` remain uncontracted so neither can be renamed into
  the canonical PAR+NIR shortwave input.
- `BeerShortwave(k)` continues to preserve its historical `k_NIR = 0.48`
  default. A future change to `k_NIR = k` must be released as a separate,
  explicit breaking migration.
- PlantBiophysics now requires PlantSimEngine 0.15 and executes hard
  dependencies directly through `run_call!(RunContext, Symbol)`.
- Removed the internal package-local hard-call compatibility helper and legacy
  direct-kernel fallback. Monteith, FvCB, FvCBIter, and ConstantAGs must run in
  a compiled `CompositeModel` when their declared hard dependencies are used.
- Removed the historical ARCHIMED YAML `read_model` parser and its parser-only
  helper API. Construct physiology models explicitly; use
  `ArchimedLight.read_models` for ARCHIMED optical model files.
- Removed the unimplemented `Translucent` MTG-array copier, the no-op
  `LightIgnore` model, and PlantBiophysics' conflicting `OpticalProperties`
  types. Couple a light producer with `outputs_to`, or omit light interception.

### Deprecations

- Use `Fvcb_net_assimilation`; the misspelled
  `Fvcb_net_assimiliation` compatibility wrapper will be removed in v0.20.
