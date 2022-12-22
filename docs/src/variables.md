# Variables

There are so many variables in PlantBiophysics that it can be difficult to remember what is their name, what are they describing or what is their unit.

Fortunately, PlantBiophysics implements a method for the `variables` function from PlantSimEngine, which helps us get all variables used in PlantBiophysics:

```@example
using PlantBiophysics, PlantSimEngine
variables(PlantBiophysics)
```
