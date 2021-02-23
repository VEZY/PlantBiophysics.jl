

file = "inputs/models/plant_coffee.yml"

@testset "read_model()" begin
    model = read_model(file)

    @test all([haskey(model,i) for i in ["Metamer","Leaf"]])

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
