file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf")
mtg = read_opf(file)

# Declare our models:
nrj = Monteith()
photo = Fvcb()
Gs = Medlyn(0.03, 12.0)
models = Dict(
    "Leaf" =>
        ModelList(
            energy_balance=nrj,
            photosynthesis=photo,
            stomatal_conductance=Gs,
            status=(d=0.03,)
        )
)
# We can compute them directly inside the MTG from available variables:
transform!(
    mtg,
    [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y) => :Rₛ,
    :Ra_PAR_f => (x -> x * 4.57) => :PPFD,
    ignore_nothing=true
)

@testset "mtg: init_mtg_models!" begin
    # Initialising all components with their corresponding models and initialisations:
    init_mtg_models!(mtg, models)

    leaf_node = get_node(mtg, 818)
    @test leaf_node[:models].photosynthesis === photo
    @test leaf_node[:models].energy_balance === nrj
    @test leaf_node[:models].stomatal_conductance === Gs
    @test status(leaf_node[:models], :Rₛ) == leaf_node[:Rₛ]
    @test status(leaf_node[:models], :PPFD) == leaf_node[:Ra_PAR_f] * 4.57
    @test status(leaf_node[:models], :d) == 0.03
end


@testset "mtg: pull_status!" begin
    leaf1 = get_node(mtg, 815)

    # Thos are the inputs we gave earlier so they are both in the mtg attr. and the model status:
    @test leaf1[:Rₛ] == status(leaf1[:models], :Rₛ)
    @test leaf1[:PPFD] == leaf1[:models][:PPFD]

    leaf1[:models].status.Rₛ = 300.0
    pull_status!(leaf1)

    # Modifying Rₛ and pulling it modifies the value in the attributes too:
    @test leaf1[:Rₛ] == 300.0

    # Make a simulation, and check the other ones:
    meteo = Atmosphere(T=22.0, Wind=0.8333, P=101.325, Rh=0.4490995)
    transform!(mtg, :models => (x -> energy_balance!(x, meteo)), ignore_nothing=true)

    # The output is not written in the attributes yet:
    @test leaf1[:A] == -999.99

    # Now it is:
    pull_status!(leaf1)
    @test leaf1[:A] == leaf1[:models][:A]

    # Checks if we can pull only some variables:
    leaf2 = get_node(mtg, 818)
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
        ignore_nothing=true
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
        date_format=DateFormat("yyyy/mm/dd")
    )

    # We can compute them directly inside the MTG from available variables:
    transform!(
        mtg,
        [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> fill(x + y, length(weather))) => :Rₛ,
        :Ra_PAR_f => (x -> x * 4.57) => :PPFD,
        (x -> 0.03) => :d,
        ignore_nothing=true
    )

    leaf_node = get_node(mtg, 816)

    # Get the Ra_PAR_f before computation to check that it is not modified
    Ra_PAR_f = copy(leaf_node[:Ra_PAR_f])
    # Get some initialisations to check if they have the same length as n steps in weather (after computation):
    sky_fraction = copy(leaf_node[:sky_fraction])

    # Make the computation:
    energy_balance!(mtg, models, weather)

    @test leaf_node[:Ra_PAR_f] == Ra_PAR_f
    @test leaf_node[:sky_fraction] == fill(sky_fraction, length(weather))
    @test leaf_node[:sky_fraction] == fill(sky_fraction, length(weather))


    # Use the values of today (05/05/2022) as a reference. Run the few lines below to update:
    # for i in [:A, :Tₗ, :Rₗₗ, :H, :λE, :Gₛ, :Gbₕ, :Gbc, :Rn, :Cᵢ, :Cₛ]
    #     print("@test leaf_node[:$i] ≈ $(round.(leaf_node[i], digits= 5)) atol = 1e-4\n")
    # end

    @test leaf_node[:A] ≈ [12.8822, 12.65021, 12.82599] atol = 1e-4
    @test leaf_node[:Tₗ] ≈ [-253.77282, -226.73428, -229.87083] atol = 1e-4
    @test leaf_node[:Rₗₗ] ≈ [-1.15294, -1.07987, -1.03496] atol = 1e-4
    @test leaf_node[:H] ≈ [-13942.29244, -14915.99942, -15075.42555] atol = 1e-4
    @test leaf_node[:λE] ≈ [14065.04046, 15038.8205, 15198.29154] atol = 1e-4
    @test leaf_node[:Gₛ] ≈ [0.33472, 0.32801, 0.32619] atol = 1e-4
    @test leaf_node[:Gbₕ] ≈ [0.02085, 0.02469, 0.02466] atol = 1e-4
    @test leaf_node[:Gbc] ≈ [0.6457, 0.76197, 0.76276] atol = 1e-4
    @test leaf_node[:Rn] ≈ [122.74802, 122.82109, 122.86599] atol = 1e-4
    @test leaf_node[:Cᵢ] ≈ [341.51361, 341.43362, 340.67958] atol = 1e-4
    @test leaf_node[:Cₛ] ≈ [360.04926, 363.39792, 363.18468] atol = 1e-4
end
