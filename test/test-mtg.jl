file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf")
mtg = read_opf(file)

# Declare our models:
nrj = Monteith()
photo = Fvcb()
Gs = Medlyn(0.03, 12.0)
models = Dict(
    "Leaf" =>
        LeafModels(
            energy = nrj,
            photosynthesis = photo,
            stomatal_conductance = Gs,
            d = 0.03
        )
)
# We can compute them directly inside the MTG from available variables:
transform!(
    mtg,
    [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y) => :Rₛ,
    :Ra_PAR_f => (x -> x * 4.57) => :PPFD,
    ignore_nothing = true
)

# Initialising all components with their corresponding models and initialisations:
init_mtg_models!(mtg, models)

@testset "mtg: init_mtg_models!" begin
    leaf_node = get_node(mtg, 2524)
    @test leaf_node[:models].photosynthesis === photo
    @test leaf_node[:models].energy === nrj
    @test leaf_node[:models].stomatal_conductance === Gs
    @test leaf_node[:models].status[:Rₛ] == leaf_node[:Rₛ]
    @test leaf_node[:models].status[:PPFD] == leaf_node[:Ra_PAR_f] * 4.57
    @test leaf_node[:models].status[:d] == 0.03
end


@testset "mtg: pull_status!" begin
    leaf1 = get_node(mtg, 2070)
    pull_status!(leaf1)
    @test leaf1[:Rₛ] == leaf1[:models][:Rₛ]
    @test leaf1[:PPFD] == leaf1[:models][:PPFD]

    leaf1[:models].status.Rₛ = 300.0
    pull_status!(leaf1)

    # Modifying Rₛ and pulling it modifies the value in the attributes too:
    @test leaf1[:Rₛ] == 300.0

    # Make a simulation, and check the other ones:
    meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)
    transform!(mtg, :models => (x -> energy_balance!(x, meteo)), ignore_nothing = true)

    # The output is not written in the attributes yet:
    @test leaf1[:A] == -999.99

    # Now it is:
    pull_status!(leaf1)
    @test leaf1[:A] == leaf1[:models][:A]

    # Checks if we can pull only some variables:
    leaf2 = get_node(mtg, 2524)
    pull_status!(leaf2, :A)
    @test leaf2[:A] == leaf2[:models][:A]
    @test leaf2[:Rn] === nothing
end


@testset "mtg: read_model" begin
    file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "models", "plant_coffee.yml")
    models = read_model(file)

    mtg = read_opf(joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf"))

    # We can compute them directly inside the MTG from available variables:
    transform!(
        mtg,
        [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y) => :Rₛ,
        :Ra_PAR_f => (x -> x * 4.57) => :PPFD,
        (x -> 0.03) => :d,
        ignore_nothing = true
    )

    # Initialising all components with their corresponding models and initialisations:
    init_mtg_models!(mtg, models)

    metamer = get_node(mtg, 2069)
    leaf = get_node(mtg, 2070)

    @test typeof(metamer[:models]) == typeof(models["Metamer"])
    @test typeof(leaf[:models]) == typeof(models["Leaf"])
end


@testset "mtg: energy_balance!" begin
    file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "models", "plant_coffee.yml")
    models = read_model(file)
    mtg = read_opf(joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf"))
    weather = read_weather(
        joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "meteo.csv"),
        :temperature => :T,
        :relativeHumidity => (x -> x ./ 100) => :Rh,
        :wind => :Wind,
        :atmosphereCO2_ppm => :Cₐ,
        date_format = DateFormat("yyyy/mm/dd")
    )

    # We can compute them directly inside the MTG from available variables:
    transform!(
        mtg,
        [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> fill(x + y, length(weather))) => :Rₛ,
        :Ra_PAR_f => (x -> x * 4.57) => :PPFD,
        (x -> 0.03) => :d,
        ignore_nothing = true
    )

    leaf_node = get_node(mtg, 2070)

    # Get the Ra_PAR_f before computation to check that it is not modified
    Ra_PAR_f = copy(leaf_node[:Ra_PAR_f])
    # Get some initialisations to check if they have the same length as n steps in weather (after computation):
    sky_fraction = copy(leaf_node[:sky_fraction])

    # Make the computation:
    energy_balance!(mtg, models, weather)


    @test leaf_node[:Ra_PAR_f] == Ra_PAR_f
    @test leaf_node[:sky_fraction] == fill(sky_fraction, length(weather))
    @test leaf_node[:sky_fraction] == fill(sky_fraction, length(weather))

    # Just use the values of today (28/02/2022) as a reference:
    @test leaf_node[:A] ≈ [33.6416, 34.0212, 33.8763] atol = 1e-4
    @test leaf_node[:Tₗ] ≈ [25.5959, 26.2083, 25.3744] atol = 1e-4
    @test leaf_node[:Rₗₗ] ≈ [-2.3841, -0.85057, -0.297067] atol = 1e-4
    @test leaf_node[:H] ≈ [28.587, 11.236, 4.418] atol = 1e-2
    @test leaf_node[:λE] ≈ [355.621, 374.506, 381.878] atol = 1e-3
    @test leaf_node[:Gₛ] ≈ [1.12406, 1.13801, 1.11500] atol = 1e-4
    @test leaf_node[:Gbₕ] ≈ [0.02026, 0.02349, 0.02296] atol = 1e-4
    @test leaf_node[:Gbc] ≈ [0.62765, 0.72508, 0.71055] atol = 1e-4
    @test leaf_node[:Rn] ≈ [384.209, 385.742, 386.296] atol = 1e-2
    @test leaf_node[:Cᵢ] ≈ [296.26, 302.97, 302.08] atol = 1e-2
    @test leaf_node[:Cₛ] ≈ [326.40, 333.08, 332.32] atol = 1e-2
end
