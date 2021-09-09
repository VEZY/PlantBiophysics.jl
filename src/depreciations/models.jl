@deprecate net_radiation!(leaf, meteo, constants) energy_balance!_(leaf, meteo, constants)
@deprecate net_radiation!(leaf, meteo) energy_balance!_(leaf, meteo)

@deprecate assimilation!(leaf, meteo, constants) photosynthesis!_(leaf, meteo, constants)
@deprecate assimilation!(leaf, meteo) photosynthesis!_(leaf, meteo)
