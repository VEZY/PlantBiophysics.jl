@gen_process_methods "light_interception" """
Computes the light interception of one or several objects based on the type of the model it was
parameterized with in `object.light_interception`, and on one or several meteorology time-steps.

At the moment, two models are implemented in the package:

- [`Beer`](@ref): the Beer-Lambert law of ligth extinction
- [`Ignore`](@ref): ignore the computation of light interception (this one is for backward
compatibility with ARCHIMED-ϕ)

# Examples

```julia
m = ModelList(light_interception=Beer(0.5), status=(LAI=2.0,))

meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)

light_interception!(m, meteo)

m[:aPAR]
```
"""