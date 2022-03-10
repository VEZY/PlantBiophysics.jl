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
    leaf_node = get_node(mtg, 816)
    @test leaf_node[:models].photosynthesis === photo
    @test leaf_node[:models].energy === nrj
    @test leaf_node[:models].stomatal_conductance === Gs
    @test status(leaf_node[:models], :Rₛ) == leaf_node[:Rₛ]
    @test status(leaf_node[:models], :PPFD) == leaf_node[:Ra_PAR_f] * 4.57
    @test status(leaf_node[:models], :d) == 0.03
end


@testset "mtg: pull_status!" begin
    leaf1 = get_node(mtg, 815)
    pull_status!(leaf1)
    @test leaf1[:Rₛ] == status(leaf1[:models], :Rₛ)
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
    leaf2 = get_node(mtg, 816)
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

    leaf_node = get_node(mtg, 815)

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
    @test leaf_node[:A] ≈ [11.31594, 11.12645, 11.29447] atol = 1e-4
    @test leaf_node[:Tₗ] ≈ [23.94156, 24.97411, 24.13802] atol = 1e-4
    @test leaf_node[:Rₗₗ] ≈ [1.01122, 1.00249, 1.11028] atol = 1e-4
    @test leaf_node[:H] ≈ [-52.71902, -60.47476, -68.89932] atol = 1e-4
    @test leaf_node[:λE] ≈ [162.72725, 170.47426, 179.00661] atol = 1e-4
    @test leaf_node[:Gₛ] ≈ [0.36235, 0.35164, 0.3481] atol = 1e-4
    @test leaf_node[:Gbₕ] ≈ [0.02072, 0.02461, 0.0247] atol = 1e-4
    @test leaf_node[:Gbc] ≈ [0.64175, 0.75955, 0.76421] atol = 1e-4
    @test leaf_node[:Rn] ≈ [110.00823, 109.99951, 110.1073] atol = 1e-4
    @test leaf_node[:Cᵢ] ≈ [331.13285, 333.70711, 332.77212] atol = 1e-4
    @test leaf_node[:Cₛ] ≈ [362.36708, 365.35128, 365.22066] atol = 1e-4
end
