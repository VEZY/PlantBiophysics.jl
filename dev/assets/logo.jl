using PlantBiophysics, MultiScaleTreeGraph, PlantGeom, CairoMakie, Dates, PlantMeteo

mtg = read_opf(joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf"))
weather = read_weather(
    joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv"),
    :temperature => :T,
    :relativeHumidity => (x -> x ./ 100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format=DateFormat("yyyy/mm/dd")
)
models = read_model(joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "models", "plant_coffee.yml"))

transform!(
    mtg,
    [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y) => :Rₛ,
    :Ra_PAR_f => (x -> x * 4.57) => :PPFD,
    (x -> 0.3) => :d,
    ignore_nothing=true
)

init_mtg_models!(mtg, models, length(weather))

run!(mtg, weather)

transform!(
    mtg,
    :Tₗ => (x -> x[1]) => :Tₗ_1,
    ignore_nothing=true
)

f = Figure(backgroundcolor=:transparent)
ax = Axis(f[1, 1], backgroundcolor=:transparent)
viz!(f[1, 1], mtg, color=:Tₗ_1)
hidespines!(ax)
hidedecorations!(ax)
f

save("./docs/src/assets/logo.svg", f)
