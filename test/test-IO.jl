

file = joinpath(dirname(dirname(pathof(PlantBiophysics))), "test", "inputs", "models", "plant_coffee.yml")

@testset "read_model()" begin
    model = read_model(file)

    @test all([haskey(model, i) for i in ["Metamer", "Leaf"]])

    model = model["Leaf"]
    @test typeof(model) <: Tuple{Vararg{AbstractModel}}
    @test typeof(model[1]) == Monteith{Float64,Int64}
    @test typeof(model[4]) == Medlyn{Float64}
    @test typeof(model[2]) == Translucent{Float64}
    @test typeof(model[3]) == Fvcb{Float64}

    @test model[4].g0 == -0.03
    @test model[4].g1 == 12.0

    @test model[2].transparency == 0.0
    @test model[2].optical_properties == σ(0.15, 0.9)

    @test model[3].VcMaxRef == 200.0 # Given in the file
    @test model[3].O₂ == 210.0 # Use default value
end;