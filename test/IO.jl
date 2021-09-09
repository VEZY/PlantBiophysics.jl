

file = "inputs/models/plant_coffee.yml"

@testset "read_model()" begin
    model = read_model(file)

    @test all([haskey(model, i) for i in ["Metamer","Leaf"]])

    model = model["Leaf"]
    # @test typeof(model)
    @test typeof(model) <: LeafModels
    @test typeof(model.stomatal_conductance) == Medlyn{Float64}
    @test typeof(model.interception) == Translucent{Float64}
    @test typeof(model.photosynthesis) == Fvcb{Float64}

    @test model.stomatal_conductance.g0 == -0.03
    @test model.stomatal_conductance.g1 == 12.0

    @test model.interception.transparency == 0.0
    @test model.interception.optical_properties == σ(0.15, 0.9)

    @test model.photosynthesis.VcMaxRef == 200.0 # Given in the file
    @test model.photosynthesis.O₂ == 210.0 # Use default value
end;

# Test reading the meteo:

file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "meteo.csv")
var_names = Dict(:temperature => :T, :relativeHumidity => :Rh, :relativeHumidity => :Rh, :wind => :Wind, :atmosphereCO2_ppm => :Cₐ)

@testset "read_weather()" begin
    meteo = read_weather(file, var_names = var_names, date_format = DateFormat("yyyy/mm/dd"))
    @test typeof(meteo) <: Weather
    @test typeof(meteo) <: Weather
    @test NamedTuple(meteo.metadata) == (;name = "Aquiares", latitude = 15.0, altitude = 100.0, use = [:Rh, :clearness], file = file)
end;
