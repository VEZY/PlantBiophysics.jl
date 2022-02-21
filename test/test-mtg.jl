

@testset "mtg: init_mtg_models!" begin
    file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf")
    mtg = read_opf(file)

    # Declare our models:
    nrj = Monteith()
    photo = Fvcb()
    gs = Medlyn(0.03, 12.0)
    models = Dict(
        "Leaf" =>
            LeafModels(
                energy = nrj,
                photosynthesis = photo,
                stomatal_conductance = gs,
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

    @test leaf_node[:leaf_model].photosynthesis === photo
    @test leaf_node[:leaf_model].energy === nrj
    @test leaf_node[:leaf_model].stomatal_conductance === gs
    @test leaf_node[:leaf_model].status[:Rₛ] == leaf_node[:Rₛ]
    @test leaf_node[:leaf_model].status[:PPFD] == leaf_node[:Ra_PAR_f] * 4.57
    @test leaf_node[:leaf_model].status[:d] == 0.03
end
