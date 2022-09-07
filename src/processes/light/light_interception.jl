"""
Light interception abstract struct. All light interception models must be a subtype of this.
"""
abstract type AbstractLightModel <: AbstractModel end

@gen_process_methods "light_interception"

"""
    light_interception(object, meteo, constants = Constants())
    light_interception!(object, meteo, constants = Constants())

Computes the light interception of one or several objects based on the type of the model it was
parameterized with in `object.light_interception`, and on one or several meteorology time-steps.

At the moment, two models are implemented in the package:

- [`Beer`](@ref): the Beer-Lambert law of ligth extinction
- [`Ignore`](@ref): ignore the computation of light interception (this one is for backward
compatibility with ARCHIMED-ϕ)

# Arguments

- `object`: a [`ModelList`](@ref), a Dict/Array of [`ModelList`](@ref), or an MTG.
- `meteo::Union{AbstractAtmosphere,Weather}`: meteorology structure, see [`Atmosphere`](@ref) or
[`Weather`](@ref)
- `constants = Constants()`: physical constants. See [`Constants`](@ref) for more details

# Note

Some models need input values for some variables. For example [`Beer`](@ref) requires a
value for `LAI`, the leaf area index. If you read the models from a file, you can
use [`init_status!`](@ref).

# Examples

```julia
m = ModelList(light_interception=Beer(0.5), status=(LAI=2.0,))

meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)

light_interception!(m, meteo)

m[:aPAR]
```
"""
light_interception!, light_interception
