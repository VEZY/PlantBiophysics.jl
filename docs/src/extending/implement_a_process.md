# Implement a new component models

```@setup usepkg
using PlantSimEngine, PlantBiophysics, PlantMeteo
PlantSimEngine.@process growth
```

## Introduction

`PlantBiophysics.jl` is based on `PlantSimEngine.jl`, a package designed to make the implementation of new processes and models easy and fast.

You'll find the documentation [here](https://virtualplantlab.github.io/PlantSimEngine.jl/stable/step_by_step/implement_a_process/).

You can also take a look at how we implement the processes in this package. For example, the photosynthesis process is implemented like so:

```julia
using PlantSimEngine
@process "photosynthesis" "...and you can add more docs in this second argument"
```

You can look at the code in `src/photosynthesis.jl`.