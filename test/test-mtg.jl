file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "scene", "opf", "coffee.opf")
mtg = read_opf(file)
models_name = Symbol(MultiScaleTreeGraph.cache_name("PlantSimEngine models"))

# Declare our models:
nrj = Monteith()
photo = Fvcb(α=0.24) # because I set-up the tests with this value for α
Gs = Medlyn(0.03, 12.0)
models = ModelMapping(:Leaf => (nrj, photo, Gs, Status(d=0.03,)))

# We can compute them directly inside the MTG from available variables:
MultiScaleTreeGraph.transform!(
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

#     @test typeof(metamer[models_name].models) == typeof(models[:Metamer].models)
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
    MultiScaleTreeGraph.transform!(
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

    rates = effective_rate_summary(ModelMapping(models), weather)
    @test rates.base_step_seconds == 1800.0 # Meteo has a timestep of 30min, so the base step should be 1800s.
    @test only(collect(keys(rates.rates))) == 1800.0 # Only one rate should be resolved for the models, which is the base step, because all models can run at meteo-rate.
    @test length(rates.rates[1800]) == 5 # 4 processes for the leaves, and 1 for the metamer

    # Make the computation:
    out = run!(
        mtg, ModelMapping(models), weather,
        tracked_outputs=Dict{Symbol,Any}(:Leaf => (:A, :Tₗ, :Ra_LW_f, :H, :λE, :Gₛ, :Gbₕ, :Gbc, :Rn, :Cᵢ, :Cₛ))
    )
    out = PlantSimEngine.convert_outputs(out, DataFrame)
    out_leaf = out[:Leaf]

    # Make the same simulation as single scale for leaf 816 to check that the values are the same as in the MTG:
    models_no_light = filter(x -> process(x) != :light_interception, models[:Leaf])
    single_scale_models = ModelMapping(models_no_light..., status=Status(d=0.03, aPPFD=leaf_node[:Ra_PAR_f] .* 4.57, Ra_SW_f=leaf_node[:Ra_SW_f], sky_fraction=leaf_node[:sky_fraction]))
    out_single = PlantSimEngine.run!(single_scale_models, weather, tracked_outputs=(:A, :Tₗ, :Ra_LW_f, :H, :λE, :Gₛ, :Gbₕ, :Gbc, :Rn, :Cᵢ, :Cₛ))

    @test leaf_node[:Ra_PAR_f] == Ra_PAR_f
    @test leaf_node[:sky_fraction] == sky_fraction

    df_leaf_node = subset(out_leaf, :node => (x -> x .== leaf_node_index))
    # Use the values of today (05/05/2022) as a reference. Run the few lines below to update:
    # for i in [:A, :Tₗ, :Ra_LW_f, :H, :λE, :Gₛ, :Gbₕ, :Gbc, :Rn, :Cᵢ, :Cₛ]
    #     print("@test df_leaf_node.$i ≈ $(round.(df_leaf_node[:, i], digits= 5)) atol = 1e-4\n")
    # end

    @test df_leaf_node.A ≈ [13.2605, 13.06977, 13.25548] atol = 1e-4
    @test df_leaf_node.Tₗ ≈ [23.89475, 24.90249, 24.05323] atol = 1e-4
    @test df_leaf_node.Ra_LW_f ≈ [1.02706, 1.04302, 1.1585] atol = 1e-4
    @test df_leaf_node.H ≈ [-55.14038, -64.83672, -74.10218] atol = 1e-4
    @test df_leaf_node.λE ≈ [180.0684, 189.7807, 199.16164] atol = 1e-4
    @test df_leaf_node.Gₛ ≈ [0.43527, 0.42403, 0.41961] atol = 1e-4
    @test df_leaf_node.Gbₕ ≈ [0.02076, 0.02467, 0.02477] atol = 1e-4
    @test df_leaf_node.Gbc ≈ [0.6429, 0.76134, 0.76613] atol = 1e-4
    @test df_leaf_node.Rn ≈ [124.92802, 124.94397, 125.05946] atol = 1e-4
    @test df_leaf_node.Cᵢ ≈ [328.90364, 332.00744, 331.1057] atol = 1e-4
    @test df_leaf_node.Cₛ ≈ [359.37384, 362.8331, 362.69801] atol = 1e-4

    # Testing that the multi-scale simulation yields similar results than the single-scale simulation
    for k in keys(out_single)
        @test df_leaf_node[:, k] == out_single[k]
        # e.g. df_leaf_node[:, :A] == out_single[:A]
    end
end