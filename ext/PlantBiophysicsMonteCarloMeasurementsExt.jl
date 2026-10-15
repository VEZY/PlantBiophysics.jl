module PlantBiophysicsMonteCarloMeasurementsExt

using PlantBiophysics
using MonteCarloMeasurements: AbstractParticles, bymap

# Floor/root selection must use each particle's state, including when some
# particles are respiring and others are assimilating in the same ensemble.
function PlantBiophysics._fvcb_assimilation(parameters::NTuple{10,T}) where {T<:AbstractParticles}
    return bymap((values...) -> PlantBiophysics._fvcb_assimilation(values), parameters...)
end

function PlantBiophysics._fvcb_ci(parameters::NTuple{3,T}) where {T<:AbstractParticles}
    return bymap((values...) -> PlantBiophysics._fvcb_ci(values), parameters...)
end

end
