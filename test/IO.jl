

model = read_model("inputs/models/plant_coffee.yml")

@testset "read_model()" begin
    @test typeof(model) == OrderedCollections.OrderedDict{String,Any}
    @test model["Group"] == "coffee" # Testing the functional Group
    @test collect(keys(model["Type"])) == ["Metamer","Leaf"] # Testing the component types
    @test model["Type"]["Leaf"]["Photosynthesis"]["use"] == "Farquharcoffee_1"
    @test model["Type"]["Leaf"]["Photosynthesis"]["Farquharcoffee_1"]["tempCRef"] == 25
end;
