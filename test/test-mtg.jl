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

    meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)
    transform!(mtg, :models => (x -> energy_balance!(x, meteo)), ignore_nothing = true)
end
