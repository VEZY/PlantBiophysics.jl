@deprecate net_radiation!(leaf, meteo, constants) run!(leaf, meteo, constants)
@deprecate net_radiation!(leaf, meteo) run!(leaf, meteo)

@deprecate assimilation!(leaf, meteo, constants) run!(leaf, meteo, constants)
@deprecate assimilation!(leaf, meteo) run!(leaf, meteo)
