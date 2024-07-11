file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf")
mtg = read_opf(file)
models_name = Symbol(MultiScaleTreeGraph.cache_name("PlantSimEngine models"))

# Declare our models:
nrj = Monteith()
photo = Fvcb(α=0.24) # because I set-up the tests with this value for α
Gs = Medlyn(0.03, 12.0)
models = Dict(
    "Leaf" =>
        (
            nrj,
            photo,
            Gs,
            Status(d=0.03,)
        )
)
# We can compute them directly inside the MTG from available variables:
transform!(
    mtg,
    [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y) => :Ra_SW_f,
    :Ra_PAR_f => (x -> x * 4.57) => :aPPFD,
    ignore_nothing=true
)

# @testset "mtg: init_mtg_models!" begin
#     # Initialising all components with their corresponding models and initialisations:
#     init_mtg_models!(mtg, models, 1, verbose=false)

#     leaf_node = get_node(mtg, 818)
#     @test leaf_node[models_name].models.photosynthesis === photo
#     @test leaf_node[models_name].models.energy_balance === nrj
#     @test leaf_node[models_name].models.stomatal_conductance === Gs
#     @test status(leaf_node[models_name], :Ra_SW_f)[1] == leaf_node[:Ra_SW_f][1]
#     @test status(leaf_node[models_name], :aPPFD)[1] == leaf_node[:Ra_PAR_f] * 4.57
#     @test status(leaf_node[models_name], :d)[1] == 0.03
# end

# @testset "mtg: read_model" begin
#     file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "models", "plant_coffee.yml")
#     models = read_model(file)

#     mtg = read_opf(joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf"))

#     # We can compute them directly inside the MTG from available variables:
#     transform!(
#         mtg,
#         [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y * 1.2) => :Rᵢ, # This would be the incident radiation
#         [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y) => :Ra_SW_f,
#         :Ra_PAR_f => (x -> x * 4.57) => :aPPFD,
#         (x -> 0.03) => :d,
#         ignore_nothing=true
#     )

#     metamer = get_node(mtg, 2069)
#     leaf = get_node(mtg, 2070)

#     @test typeof(metamer[models_name].models) == typeof(models["Metamer"].models)
#     @test typeof(status(metamer[models_name])) <: TimeStepTable{<:Status}
# end

@testset "mtg: run!" begin
    file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "models", "plant_coffee.yml")
    models = read_model(file)

    mtg = read_opf(joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf"))
    weather = read_weather(
        joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv"),
        :temperature => :T,
        :relativeHumidity => (x -> x ./ 100) => :Rh,
        :wind => :Wind,
        :atmosphereCO2_ppm => :Cₐ,
        date_format=DateFormat("yyyy/mm/dd")
    )

    # We can compute them directly inside the MTG from available variables:
    transform!(
        mtg,
        [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> x + y * 1.2) => :Rᵢ, # This would be the incident radiation
        [:Ra_PAR_f, :Ra_NIR_f] => ((x, y) -> fill(x + y, length(weather))) => :Ra_SW_f,
        :Ra_PAR_f => (x -> fill(x, length(weather))) => :Ra_PAR_f,
        :sky_fraction => (x -> fill(x, length(weather))) => :sky_fraction,
        (x -> 0.03) => :d,
        ignore_nothing=true
    )

    leaf_node_index = 816
    leaf_node = get_node(mtg, leaf_node_index)

    # attr_name = MultiScaleTreeGraph.cache_name("PlantSimEngine models")
    # @edit PlantSimEngine.init_mtg_models!(mtg, models, attr_name=attr_name)
    # node = get_node(mtg, 816)
    # node[attr_name]

    # Get the Ra_PAR_f before computation to check that it is not modified
    Ra_PAR_f = copy(leaf_node[:Ra_PAR_f])
    # Get some initialisations to check if they have the same length as n steps in weather (after computation):
    sky_fraction = copy(leaf_node[:sky_fraction])

    # Initialising all components with their corresponding models and initialisations:
    # init_mtg_models!(mtg, models, length(weather))

    # Make the computation:
    out = run!(mtg, models, weather, outputs=Dict{String,Any}("Leaf" => (:A, :Tₗ, :Ra_LW_f, :H, :λE, :Gₛ, :Gbₕ, :Gbc, :Rn, :Cᵢ, :Cₛ)))
    out_leaf = outputs(out)["Leaf"]

    @test leaf_node[:Ra_PAR_f] == Ra_PAR_f
    @test leaf_node[:sky_fraction] == sky_fraction

    # Use the values of today (05/05/2022) as a reference. Run the few lines below to update:
    # for i in [:A, :Tₗ, :Ra_LW_f, :H, :λE, :Gₛ, :Gbₕ, :Gbc, :Rn, :Cᵢ, :Cₛ]
    #     print("@test leaf_node[:$i] ≈ $(round.(leaf_node[i], digits= 5)) atol = 1e-4\n")
    # end

    @test [ts[leaf_node_index] for ts in out_leaf[:A]] ≈ [15.02811551295279, 14.84360130865809, 15.042350741959263] atol = 1e-4
    @test [ts[leaf_node_index] for ts in out_leaf[:Tₗ]] ≈ [23.893099204266356, 24.874829296660252, 24.015679403940453] atol = 1e-4
    @test [ts[leaf_node_index] for ts in out_leaf[:Ra_LW_f]] ≈ [1.14627541299134, 1.1914837843642352, 1.3296911902332498] atol = 1e-4
    @test [ts[leaf_node_index] for ts in out_leaf[:H]] ≈ [-55.228872186188084, -66.52995979765936, -76.41569370159633] atol = 1e-4
    @test [ts[leaf_node_index] for ts in out_leaf[:λE]] ≈ [194.70453907867162, 206.0508350615158, 216.07477637132178] atol = 1e-4
    @test [ts[leaf_node_index] for ts in out_leaf[:Gₛ]] ≈ [0.5014258543060032, 0.4901245596622712, 0.48491464428223297] atol = 1e-4
    @test [ts[leaf_node_index] for ts in out_leaf[:Gbₕ]] ≈ [0.020762064267331817, 0.024689460654883366, 0.024791460561489252] atol = 1e-4
    @test [ts[leaf_node_index] for ts in out_leaf[:Gbc]] ≈ [0.6429369392329636, 0.7620005006226626, 0.766943182562655] atol = 1e-4
    @test [ts[leaf_node_index] for ts in out_leaf[:Rn]] ≈ [139.47566689248353, 139.52087526385642, 139.65908266972545] atol = 1e-4
    @test [ts[leaf_node_index] for ts in out_leaf[:Cᵢ]] ≈ [326.6484086881649, 330.23157818958396, 329.3630716711602] atol = 1e-4
    @test [ts[leaf_node_index] for ts in out_leaf[:Cₛ]] ≈ [356.6258328058089, 360.52022105427915, 360.3866165265373] atol = 1e-4
end
