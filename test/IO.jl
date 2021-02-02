

file = "inputs/models/plant_coffee.yml"

@testset "read_model()" begin
    model = read_model(file)
    # @test typeof(model)
    @test collect(keys(model)) == ["StomatalConductance","Interception","Photosynthesis"]
    @test typeof(model["StomatalConductance"]) == Medlyn{Float64}
    @test typeof(model["Interception"]) == Translucent{Float64}
    @test typeof(model["Photosynthesis"]) == Fvcb{Float64}

    @test model["StomatalConductance"].g0 == -0.03
    @test model["StomatalConductance"].g1 == 12.0

    @test model["Interception"].transparency == 0.0
    @test model["Interception"].optical_properties == σ(0.15, 0.9)

    @test model["Photosynthesis"].VcMaxRef == 200.0 # Given in the file
    @test model["Photosynthesis"].O₂ == 210.0 # Use default value
end;
