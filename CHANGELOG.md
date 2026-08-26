# Changelog

## Unreleased

### Breaking changes

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
