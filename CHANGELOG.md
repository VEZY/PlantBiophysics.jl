# Changelog

## Unreleased

### Breaking changes

- PlantBiophysics now requires PlantSimEngine 0.15 and executes hard
  dependencies directly through `run_call!(RunContext, Symbol)`.
- Removed the internal package-local hard-call compatibility helper and legacy
  direct-kernel fallback. Monteith, FvCB, FvCBIter, and ConstantAGs must run in
  a compiled `CompositeModel` when their declared hard dependencies are used.
