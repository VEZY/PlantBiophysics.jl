"""
Ignore model for light interception, see [here](https://archimed-platform.github.io/archimed-phys-user-doc/3-inputs/5-models/2-models_list/).
Make the mesh invisible, and not computed. Can save a lot of time for the computations when there are components types
that are not visible anyway (e.g. inside others).
"""
struct Ignore <: InterceptionModel end
